-- صفٌّ للمجهول في سجلّ التوليد — وإلّا فالحصّة حبرٌ على ورق.
--
-- `quotaGate` تعدّ نداءات كل منادٍ من `generation_logs`، وتكتب للمجهول
-- «تذكرةً» قبل الإنفاق: إن لم تُكتب فلا يُعدّ، وإن لم يُعدّ فحصّته
-- لانهائية بينما تقول الشيفرة إنها عشرون.
--
-- وقد جرّبتُ الكتابة فعلًا قبل النشر فرجع:
--   23503 … "generation_logs_merchant_id_fkey" — Key (merchant_id)=
--   (00000000-…-000000000000) is not present in table "merchants".
--
-- فالمعرّف الصفريّ لا يصلح مرساةً: `merchants.id` نفسه مرتبطٌ بـ
-- `auth.users`، فإسناد المجهول إلى صفٍّ وهميّ يوجب اختلاق **مستخدمٍ**
-- في جدول المصادقة — عبثٌ بجدولٍ تملكه خدمةٌ أخرى، لأجل عمودٍ تحليليّ.
--
-- والصواب أن يُقال ما هو واقع: نداء المجهول **لا صاحب له**. فالعمود
-- يقبل `null`، والمفتاح الأجنبيّ يبقى كما هو — إذ لا يفحص المفتاح
-- الأجنبيّ الفراغ أصلًا — فلا نخسر تتالي الحذف عند حذف تاجر حقيقي.
--
-- ولا صفَّ قائمًا يتأثّر: العمود كان إلزاميًّا، فكلّ ما فيه منسوبٌ إلى
-- تاجر، ورفعُ الإلزام لا يغيّر ماضيًا بل يسمح بمستقبل.

alter table public.generation_logs
  alter column merchant_id drop not null;

comment on column public.generation_logs.merchant_id is
  'صاحب التوليد. `null` = نداءٌ مجهول (نسخة قديمة لا ترسل هويّة)، ويأخذ حصّةً صغيرة مشتركة.';

-- ولوحة الإدارة كانت تسمّي كل من لا اسم له «تاجر»، فيصير الزائر
-- المجهول تاجرًا في العرض — رقمٌ يكذب بلا خطأ في الحساب.
create or replace function public.generation_feed(p_limit integer default 30)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public', 'pg_temp'
as $function$
declare v_uid uuid := auth.uid(); v_admin boolean;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  v_admin := public.is_platform_admin();

  return jsonb_build_object('ok', true, 'items', coalesce((
    select jsonb_agg(s.row order by s.at desc) from (
      select g.created_at as at, jsonb_build_object(
        'id', g.id,
        'merchant', coalesce(
          nullif(m.business_name, ''),
          case when g.merchant_id is null then 'زائر' else 'تاجر' end),
        'anonymous', g.merchant_id is null,
        'platform', g.platform, 'brief', g.brief, 'model', g.model,
        'status', g.status, 'error_code', g.error_code,
        'cost_usd', g.cost_usd, 'cost_sar', round(coalesce(g.cost_usd,0) * 3.75, 4),
        'tokens_in', g.tokens_in, 'tokens_out', g.tokens_out, 'latency_ms', g.latency_ms,
        'image_url', g.output_image_url, 'video_url', g.output_video_url,
        'media_kind', g.media_kind, 'created_at', g.created_at,
        'variants', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'id', v.id, 'angle', v.angle, 'rank', v.rank,
                   'headline', v.headline, 'body', v.body, 'cta', v.cta,
                   'hashtags', v.hashtags, 'score', v.score_total,
                   'fix', v.fix_note, 'action', v.action, 'edited', v.edited_output,
                   'image_url', v.image_url, 'image_verified', v.image_verified)
                 order by v.rank nulls last)
          from public.ad_variants v where v.generation_id = g.id), '[]'::jsonb)
      ) as row
      from public.generation_logs g
      left join public.merchants m on m.id = g.merchant_id
      where v_admin or g.merchant_id = v_uid
      order by g.created_at desc
      limit greatest(1, least(coalesce(p_limit,30), 100))
    ) s), '[]'::jsonb),
    'summary', (
      select jsonb_build_object(
        'total', count(*), 'ok', count(*) filter (where g2.status = 'ok'),
        'failed', count(*) filter (where g2.status = 'error'),
        'anonymous', count(*) filter (where g2.merchant_id is null),
        'with_media', count(*) filter (where g2.output_image_url is not null or g2.output_video_url is not null),
        'cost_sar', round(coalesce(sum(g2.cost_usd),0) * 3.75, 2),
        'cost_sar_30d', round(coalesce(sum(g2.cost_usd) filter (where g2.created_at >= now() - interval '30 days'),0) * 3.75, 2),
        'avg_ms', round(avg(g2.latency_ms))
      ) from public.generation_logs g2
      where v_admin or g2.merchant_id = v_uid
    ));
end $function$;

-- فهرسٌ صغير للعدّ: بوّابة الحصّة تسأل «كم نداءً مجهولًا بهذا المفتاح
-- خلال يوم؟» عند **كل** نداء، ومسحُ الجدول كلّه يكبر بكبره.
create index if not exists generation_logs_anon_quota_idx
  on public.generation_logs (prompt_key, created_at)
  where merchant_id is null;
