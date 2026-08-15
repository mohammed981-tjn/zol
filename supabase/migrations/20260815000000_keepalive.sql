-- إبقاء المشروع حيًّا على الخطة المجانية.
--
-- Supabase توقف مشاريع الخطة المجانية إذا قلّ نشاط القاعدة على مدى ٧ أيام،
-- والتوثيق يقول إن «بضعة طلبات مستخدم للقاعدة كل يوم» تكفي لتفادي الإيقاف.
-- لذا الجدولة هنا كل ٨ ساعات (٣ مرات يوميًا) لا كل يومين: كل يوم بلا طلبات
-- هو يوم يُحسب خاملًا في نافذة الأسبوع.
--
-- الطلب يخرج من القاعدة عبر pg_net إلى واجهة REST العامة ثم يعود إلى Postgres
-- كطلب anon حقيقي — لا استعلامًا داخليًا قد لا يُحتسب نشاطًا.

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- الهدف الذي يُستدعى: لا يقرأ بيانات ولا يكتبها، يعيد الوقت فقط.
create or replace function public.keepalive()
returns timestamptz
language sql
stable
security invoker
set search_path = ''
as $fn$
  select now()
$fn$;

comment on function public.keepalive() is
  'نبضة إبقاء المشروع نشطًا. تعيد الوقت فقط ولا تلمس أي جدول.';

revoke all on function public.keepalive() from public;
grant execute on function public.keepalive() to anon, authenticated;

-- سجل النبضات: للتشخيص عند الشك في توقف الجدولة.
create table if not exists public.keepalive_log (
  id          bigint generated always as identity primary key,
  ran_at      timestamptz not null default now(),
  request_id  bigint
);

-- RLS مفعّل بلا أي سياسة = الجدول غير مرئي إطلاقًا عبر الواجهة العامة.
alter table public.keepalive_log enable row level security;
revoke all on table public.keepalive_log from anon, authenticated;

create index if not exists keepalive_log_ran_at_idx
  on public.keepalive_log (ran_at desc);

-- الدالة التي ينفّذها المجدول. search_path يشمل net و extensions معًا لأن
-- pg_net قد يركّب دواله في أيٍّ منهما حسب إصدار المنصة.
create or replace function public._keepalive_tick()
returns void
language plpgsql
security definer
set search_path = net, extensions, public
as $fn$
declare
  v_request_id bigint;
begin
  select http_post(
    url     := 'https://fbbrkwragezhztffbvxf.supabase.co/rest/v1/rpc/keepalive',
    body    := '{}'::jsonb,
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'apikey',        'sb_publishable_l6cZctfpZSOquWbRdxg6hw_ulgI1kbM',
                 'Authorization', 'Bearer sb_publishable_l6cZctfpZSOquWbRdxg6hw_ulgI1kbM'
               )
  ) into v_request_id;

  insert into public.keepalive_log (request_id) values (v_request_id);
end;
$fn$;

revoke all on function public._keepalive_tick() from public, anon, authenticated;

-- الجدولة: ٠٣:٢٣ و ١١:٢٣ و ١٩:٢٣ بتوقيت UTC.
-- الدقيقة ٢٣ لا ٠٠ تفاديًا لازدحام رأس الساعة على المنصة.
do $sched$
begin
  if exists (select 1 from cron.job where jobname = 'adcraft-keepalive') then
    perform cron.unschedule('adcraft-keepalive');
  end if;

  perform cron.schedule(
    'adcraft-keepalive',
    '23 3,11,19 * * *',
    'select public._keepalive_tick();'
  );
end;
$sched$;
