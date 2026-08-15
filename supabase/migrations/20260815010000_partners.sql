-- واجهة الشركاء: بيع قدرة توليد الإعلان لمشاريع خارجية.
--
-- الشريك يستهلك القدرة ولا يملكها: لا يرى البرومبتات ولا المفاتيح ولا
-- الشيفرة، ويُقاس استهلاكه ويُوقَف بضغطة. مفتاحه يُخزَّن مُجزّأً لا نصًّا —
-- تسريب القاعدة لا يسلّم مفاتيح الشركاء.
--
-- الشريك مربوط بحساب تاجر قائم، فلا يحتاج `ad-copy` ولا `generation_logs`
-- أي تعديل: كل توليدة تُنسب وتُسعَّر وتظهر في لوحة الإدارة كما اليوم.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.partners (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  slug          text not null unique,
  merchant_id   uuid not null references public.merchants(id) on delete restrict,
  monthly_quota integer not null default 100,
  is_active     boolean not null default true,
  notes         text,
  created_at    timestamptz not null default now()
);

comment on column public.partners.monthly_quota is
  'حصة شهرية ثابتة. غيّرها بـupdate، أو اجعلها -1 لتعني بلا حد.';

create table if not exists public.partner_api_keys (
  id           uuid primary key default gen_random_uuid(),
  partner_id   uuid not null references public.partners(id) on delete cascade,
  key_hash     text not null unique,
  key_prefix   text not null,
  last_used_at timestamptz,
  revoked_at   timestamptz,
  created_at   timestamptz not null default now()
);

create index if not exists partner_api_keys_partner_idx
  on public.partner_api_keys (partner_id) where revoked_at is null;

-- RLS مفعّل بلا أي سياسة: الجدولان غير مرئيين عبر الواجهة العامة إطلاقًا.
-- الوصول الوحيد عبر الدوال أدناه، وكلها security definer بفحص صلاحية.
alter table public.partners        enable row level security;
alter table public.partner_api_keys enable row level security;
revoke all on table public.partners        from anon, authenticated;
revoke all on table public.partner_api_keys from anon, authenticated;

-- التجزئة في مكان واحد: أي اختلاف بين التوليد والتحقق يعطّل كل المفاتيح.
create or replace function public._partner_hash(p_key text)
returns text
language sql
immutable
security definer
set search_path = extensions, public
as $fn$
  select encode(digest(p_key, 'sha256'), 'hex')
$fn$;

revoke all on function public._partner_hash(text) from public, anon, authenticated;

/*
 * مصادقة الشريك وفحص حصته في نداء واحد.
 *
 * تُستدعى من دالة الحافة بمفتاح service_role، لا من العميل. تعيد jsonb
 * دائمًا ولا ترمي: دالة الحافة تترجم `error` إلى رمز HTTP مناسب.
 */
create or replace function public.partner_authenticate(p_key text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_key     public.partner_api_keys;
  v_partner public.partners;
  v_used    integer;
begin
  select * into v_key
  from public.partner_api_keys
  where key_hash = public._partner_hash(p_key) and revoked_at is null;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid_key');
  end if;

  select * into v_partner from public.partners where id = v_key.partner_id;

  if not v_partner.is_active then
    return jsonb_build_object('ok', false, 'error', 'partner_suspended');
  end if;

  -- التوليدات الفاشلة لا تُحتسب: الشريك لا يدفع ثمن عطل عندنا.
  select count(*) into v_used
  from public.generation_logs
  where merchant_id = v_partner.merchant_id
    and status = 'ok'
    and created_at >= date_trunc('month', now());

  if v_partner.monthly_quota >= 0 and v_used >= v_partner.monthly_quota then
    return jsonb_build_object(
      'ok', false, 'error', 'quota_exceeded',
      'used', v_used, 'quota', v_partner.monthly_quota
    );
  end if;

  update public.partner_api_keys set last_used_at = now() where id = v_key.id;

  return jsonb_build_object(
    'ok', true,
    'partner_id',  v_partner.id,
    'name',        v_partner.name,
    'merchant_id', v_partner.merchant_id,
    'quota',       v_partner.monthly_quota,
    'used',        v_used,
    'remaining',   case when v_partner.monthly_quota < 0 then -1
                        else v_partner.monthly_quota - v_used end
  );
end;
$fn$;

revoke all on function public.partner_authenticate(text) from public, anon, authenticated;

-- ═══ دوال الإدارة ═══

create or replace function public.partner_create(
  p_name        text,
  p_slug        text,
  p_merchant_id uuid,
  p_quota       integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare v_id uuid;
begin
  if not public.is_platform_admin() then
    return jsonb_build_object('ok', false, 'error', 'admin_only');
  end if;

  insert into public.partners (name, slug, merchant_id, monthly_quota)
  values (p_name, p_slug, p_merchant_id, p_quota)
  returning id into v_id;

  return jsonb_build_object('ok', true, 'partner_id', v_id);
end;
$fn$;

/*
 * يصدر مفتاحًا جديدًا ويعيده نصًّا **مرة واحدة فقط**.
 *
 * المخزَّن تجزئته لا نصّه، فلا سبيل لعرضه ثانيةً — وهذا مقصود: مفتاح
 * يمكن استرجاعه من القاعدة مفتاحٌ يمكن سرقته منها.
 */
create or replace function public.partner_issue_key(p_partner_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_key    text;
  v_prefix text;
begin
  if not public.is_platform_admin() then
    return jsonb_build_object('ok', false, 'error', 'admin_only');
  end if;

  if not exists (select 1 from public.partners where id = p_partner_id) then
    return jsonb_build_object('ok', false, 'error', 'partner_not_found');
  end if;

  v_key := 'pk_live_' || encode(gen_random_bytes(24), 'hex');
  v_prefix := left(v_key, 16);

  insert into public.partner_api_keys (partner_id, key_hash, key_prefix)
  values (p_partner_id, public._partner_hash(v_key), v_prefix);

  return jsonb_build_object(
    'ok', true, 'key', v_key, 'prefix', v_prefix,
    'note', 'انسخه الآن — لن يُعرض مرة أخرى.'
  );
end;
$fn$;

create or replace function public.partner_revoke_key(p_key_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if not public.is_platform_admin() then
    return jsonb_build_object('ok', false, 'error', 'admin_only');
  end if;

  update public.partner_api_keys set revoked_at = now()
  where id = p_key_id and revoked_at is null;

  return jsonb_build_object('ok', true, 'revoked', found);
end;
$fn$;

/** قائمة الشركاء باستهلاك الشهر — تغذّي تبويب الشركاء في لوحة الإدارة. */
create or replace function public.partner_list()
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if not public.is_platform_admin() then
    return jsonb_build_object('ok', false, 'error', 'admin_only');
  end if;

  return jsonb_build_object('ok', true, 'items', coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'name', p.name, 'slug', p.slug,
      'quota', p.monthly_quota, 'is_active', p.is_active,
      'created_at', p.created_at,
      'used', (select count(*) from public.generation_logs g
               where g.merchant_id = p.merchant_id and g.status = 'ok'
                 and g.created_at >= date_trunc('month', now())),
      'cost_sar', (select round(coalesce(sum(g.cost_usd), 0) * 3.75, 4)
                   from public.generation_logs g
                   where g.merchant_id = p.merchant_id
                     and g.created_at >= date_trunc('month', now())),
      'keys', coalesce((select jsonb_agg(jsonb_build_object(
                          'id', k.id, 'prefix', k.key_prefix,
                          'last_used_at', k.last_used_at,
                          'revoked', k.revoked_at is not null)
                        order by k.created_at desc)
                        from public.partner_api_keys k where k.partner_id = p.id),
                       '[]'::jsonb)
    ) order by p.created_at desc)
    from public.partners p
  ), '[]'::jsonb));
end;
$fn$;

grant execute on function public.partner_create(text, text, uuid, integer) to authenticated;
grant execute on function public.partner_issue_key(uuid)  to authenticated;
grant execute on function public.partner_revoke_key(uuid) to authenticated;
grant execute on function public.partner_list()           to authenticated;
