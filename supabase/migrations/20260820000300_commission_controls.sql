-- ضبط العمولات: على المطبعة، وعلى التاجر.
--
-- `print_shops.commission_rate` موجود منذ بُني الجدول ولا زرّ يضبطه —
-- فالنسبة تُكتب مرّة عند الإنشاء ثم لا تتغيّر إلا بيد من يفتح القاعدة.
-- والتاجر لا حقل عمولة له إطلاقًا.
--
-- **والافتراض هنا صفر عن قصد**: رسم التاجر يبدأ معطّلًا فلا يتغيّر ما
-- يدفعه أحدٌ بمجرّد تطبيق هذه الهجرة. تفعيلُه قرارُ صاحب المنصّة يتّخذه
-- بزرّ، لا أثرٌ جانبيّ لترحيلٍ في قاعدة البيانات.

-- ── ١) عمولة المطبعة ────────────────────────────────────────────────
create or replace function public.admin_set_shop_commission(
  p_shop_id uuid,
  p_rate numeric
) returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
begin
  if not public.is_platform_admin() then
    return jsonb_build_object('ok', false, 'error', 'admin_only');
  end if;
  -- حدٌّ أعلى معقول: نسبةٌ فوق النصف ليست عمولةً بل استحواذًا، وغالبًا
  -- خطأُ إدخالٍ (‏`1500`‎ بدل `15`). ورقمٌ سالب يقلب الاتجاه فيدفع
  -- المنصّةُ للمطبعة عن كل طلب.
  if p_rate is null or p_rate < 0 or p_rate > 50 then
    return jsonb_build_object('ok', false, 'error', 'rate_out_of_range');
  end if;
  if not exists (select 1 from public.print_shops where id = p_shop_id) then
    return jsonb_build_object('ok', false, 'error', 'shop_not_found');
  end if;

  update public.print_shops
     set commission_rate = p_rate, updated_at = now()
   where id = p_shop_id;

  return jsonb_build_object('ok', true, 'shop_id', p_shop_id, 'rate', p_rate);
end; $fn$;

revoke all on function public.admin_set_shop_commission(uuid, numeric) from public;
grant execute on function public.admin_set_shop_commission(uuid, numeric) to authenticated;

-- ── ٢) رسم المنصّة على التاجر ───────────────────────────────────────
--
-- يُخزَّن في نفس جدول الإعدادات الذي يقرأ منه `print_order_create`
-- رسمَ التوصيل ونسبةَ الضريبة (`setting_num`)، فلا يُخترع مكانٌ ثالث
-- للمال.
insert into public.app_settings (key, value)
values ('merchant_fee_rate', '0')
on conflict (key) do nothing;

create or replace function public.admin_set_merchant_fee(
  p_rate numeric
) returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
begin
  if not public.is_platform_admin() then
    return jsonb_build_object('ok', false, 'error', 'admin_only');
  end if;
  if p_rate is null or p_rate < 0 or p_rate > 25 then
    return jsonb_build_object('ok', false, 'error', 'rate_out_of_range');
  end if;

  insert into public.app_settings (key, value)
  values ('merchant_fee_rate', p_rate::text)
  on conflict (key) do update set value = excluded.value;

  return jsonb_build_object('ok', true, 'rate', p_rate);
end; $fn$;

revoke all on function public.admin_set_merchant_fee(numeric) from public;
grant execute on function public.admin_set_merchant_fee(numeric) to authenticated;

-- ── ٣) شرح العائد بالأرقام ──────────────────────────────────────────
--
-- الوعاء الذي تُحسب عليه العمولة سؤالٌ يُحسم بالنظر لا بالشرح: الدالّة
-- تعرض الوعاءين معًا على طلبٍ افتراضي، فيرى صاحب المنصّة أثر اختياره
-- قبل أن يختار. والعمولة اليوم على المبلغ **شامل الضريبة**، وحصّته منها
-- تحمل ضريبتها — وهو ما يخفي أن صافيه أقلّ ممّا يظنّ.
create or replace function public.commission_preview(
  p_items_total numeric,
  p_rate numeric
) returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
declare
  v_fee   numeric := public.setting_num('delivery_fee', 25);
  v_vat_r numeric := public.setting_num('vat_rate', 0.15);
  v_total numeric := round(p_items_total + v_fee, 2);
  v_vat   numeric := round(v_total * v_vat_r / (1 + v_vat_r), 2);
  v_gross numeric := round(p_items_total * p_rate / 100, 2);
  v_net   numeric := round(p_items_total / (1 + v_vat_r) * p_rate / 100, 2);
begin
  if not public.is_platform_admin() then
    return jsonb_build_object('ok', false, 'error', 'admin_only');
  end if;
  return jsonb_build_object(
    'ok', true,
    'items_total', p_items_total,
    'delivery_fee', v_fee,
    'grand_total', v_total,
    'vat_included', v_vat,
    -- الوعاء الحالي: العمولة على المبلغ شامل الضريبة.
    'cut_on_gross', v_gross,
    'cut_on_gross_after_vat', round(v_gross / (1 + v_vat_r), 2),
    -- والوعاء البديل: على الصافي قبل الضريبة.
    'cut_on_net', v_net,
    'shop_net_now', round(p_items_total - v_gross, 2)
  );
end; $fn$;

revoke all on function public.commission_preview(numeric, numeric) from public;
grant execute on function public.commission_preview(numeric, numeric) to authenticated;
