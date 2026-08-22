-- طلبات التسعير — إغلاق أشدّ الطرق المسدودة في السوق.
--
-- كان زرّ «اطلب تسعيرة» يعرض إشعارًا ثم لا شيء. والإشعار كان صادقًا
-- (يقول إن الطلب لا يصل بعد)، لكن الصدق عن طريق مسدود لا يفتحه: التاجر
-- يرى مزوّدًا يناسبه ولا يملك أن يكلّمه، فيخرج من السوق ولا يعود.
--
-- وثلاثة قرارات تحكم الجدول:
--
--   ١) **الطلب يخصّ طرفين ولا يراه ثالث.** لا سياسة قراءة عامّة هنا
--      البتّة: نصّ الطلب فيه ما يبيعه التاجر وميزانيته وهاتفه، وهذه
--      بيانات تجارية لا تُعرض في دليل.
--
--   ٢) **المزوّد يقرأ ما أُرسل إليه فقط.** الربط عبر `service_providers`
--      لا عبر عمود اسم: من غيّر اسمه لا يقرأ طلبات غيره.
--
--   ٣) **الحالة يملكها المزوّد، والنصّ يملكه التاجر.** فلا يبدّل مزوّدٌ
--      ما طُلب منه ثم يزعم أنه نفّذه، ولا يبدّل تاجرٌ حالةَ «رُدّ عليه»
--      ليبدو أن أحدًا لم يردّ.

create table if not exists public.quote_requests (
  id            uuid primary key default gen_random_uuid(),

  provider_id   uuid not null references public.service_providers(id)
                  on delete cascade,
  merchant_id   uuid not null references public.merchants(id)
                  on delete cascade,

  -- ما يريده التاجر، بصياغته. الحقول المفصّلة تأتي حين نعرف ما يسأل عنه
  -- المزوّدون فعلًا — وتخمينُها الآن يُنتج نموذجًا طويلًا لا يُملأ.
  body          text not null,

  -- ميزانية تقريبية بالريال. صفر يعني «لم يذكر» — وهو الشائع في أول
  -- رسالة، وإلزامُه يوقف الطلب قبل أن يبدأ.
  budget_sar    integer not null default 0,

  -- كيف يردّ المزوّد: هاتف أو واتساب أو بريد، كما كتبه التاجر.
  contact       text not null,

  status        text not null default 'sent',
  provider_note text,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint quote_requests_status_valid
    check (status in ('sent', 'seen', 'answered', 'declined')),
  constraint quote_requests_budget_sane
    check (budget_sar >= 0 and budget_sar <= 10000000),
  constraint quote_requests_text_bounded
    check (length(body) between 10 and 2000
           and length(contact) between 5 and 120)
);

create index if not exists quote_requests_provider_idx
  on public.quote_requests (provider_id, created_at desc);

create index if not exists quote_requests_merchant_idx
  on public.quote_requests (merchant_id, created_at desc);

alter table public.quote_requests enable row level security;

-- التاجر يرى طلباته هو.
drop policy if exists quote_requests_read_own on public.quote_requests;
create policy quote_requests_read_own
  on public.quote_requests for select
  to authenticated
  using (merchant_id = auth.uid());

-- والمزوّد يرى ما أُرسل إلى إدراجه هو.
drop policy if exists quote_requests_read_addressed on public.quote_requests;
create policy quote_requests_read_addressed
  on public.quote_requests for select
  to authenticated
  using (
    exists (
      select 1 from public.service_providers p
       where p.id = provider_id and p.owner_id = auth.uid()
    )
  );

-- الإرسال باسم المرسِل نفسه، وإلى إدراج معتمَد وحده: طلبٌ إلى مزوّد
-- معلَّق أو مرفوض لا يقرأه أحد، والتاجر ينتظر ردًّا مستحيلًا.
drop policy if exists quote_requests_insert_own on public.quote_requests;
create policy quote_requests_insert_own
  on public.quote_requests for insert
  to authenticated
  with check (
    merchant_id = auth.uid()
    and exists (
      select 1 from public.service_providers p
       where p.id = provider_id and p.status = 'approved'
    )
  );

-- التحديث للمزوّد المخاطَب وحده — والحارس أدناه يحصره في الحالة
-- والملاحظة.
drop policy if exists quote_requests_update_addressed on public.quote_requests;
create policy quote_requests_update_addressed
  on public.quote_requests for update
  to authenticated
  using (
    exists (
      select 1 from public.service_providers p
       where p.id = provider_id and p.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.service_providers p
       where p.id = provider_id and p.owner_id = auth.uid()
    )
  );

drop policy if exists quote_requests_admin_all on public.quote_requests;
create policy quote_requests_admin_all
  on public.quote_requests for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- الحارس: سياسة الصفّ لا تحمي **عمودًا**.
--
-- بلا هذا يستطيع المزوّد المخاطَب أن يُعيد كتابة نصّ الطلب وميزانيته ثم
-- يحتجّ بما «طُلب منه». ويستطيع أن ينقله إلى تاجر آخر بتبديل
-- `merchant_id`. والمنع في القاعدة لا في الواجهة.
create or replace function public.quote_request_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  new.updated_at := now();

  if tg_op = 'INSERT' then
    if not public.is_platform_admin() then
      new.status := 'sent';
      new.provider_note := null;
    end if;
    return new;
  end if;

  if not public.is_platform_admin() then
    new.provider_id := old.provider_id;
    new.merchant_id := old.merchant_id;
    new.body        := old.body;
    new.budget_sar  := old.budget_sar;
    new.contact     := old.contact;
    new.created_at  := old.created_at;
  end if;

  return new;
end;
$fn$;

drop trigger if exists quote_request_guard_trg on public.quote_requests;
create trigger quote_request_guard_trg
  before insert or update on public.quote_requests
  for each row execute function public.quote_request_guard();
