-- لوحة تسجيل المزوّدين — تحويل السوق من دليل ثابت إلى سوق حقيقي.
--
-- الدليل اليوم في `lib/models/ad_service.dart`: تسعة مزوّدين مكتوبين في
-- ملفّ داخل التطبيق. أثر ذلك أن كل مزوّد جديد يحتاج بناءً ونشرًا وتحديثًا
-- على كل جهاز، وأن السوق مهما كبر يبقى قائمةً نكتبها نحن — وهذا ليس
-- سوقًا بل كتيّب.
--
-- هنا يسجّل المزوّد نفسه، ويُراجَع، ثم يظهر. ثلاثة قرارات تحكم التصميم:
--
--   ١) **التسجيل لا يعني الظهور.** الحالة تبدأ `pending`، ولا يرى العامّة
--      إلا `approved`. سوقٌ يظهر فيه كل من سجّل يمتلئ في أسبوع بمن لا
--      يقدّم خدمة، ويفقد التاجرُ الثقةَ في أوّل تجربة سيّئة — والثقة لا
--      تُستعاد بحذف صفّ من جدول.
--
--   ٢) **المزوّد لا يوثّق نفسه ولا يعتمد نفسه.** هذا ليس افتراضَ سوء نيّة
--      بل بناءٌ لا يحتاج حُسن النيّة: زرّ في تطبيق العميل يستطيع أي أحد
--      استدعاءه بأدوات عامّة. المنع في القاعدة لا في الواجهة.
--
--   ٣) **لا تقييمات مخترَعة.** `rating` و`reviews` تبقيان فارغتين حتى
--      يوجد طلب حقيقي يُقيَّم. الدليل الحالي يحمل «٤٫٦ من ١٢٨ مراجعة»
--      وهي أرقام كتبناها — تُعرض بلا تقييم أصدق من تُعرض بتقييم كاذب.

create table if not exists public.service_providers (
  id                uuid primary key default gen_random_uuid(),

  -- صاحب الإدراج: حساب تاجر قائم. المزوّد في سوقنا تاجرٌ أيضًا، فلا
  -- نحتاج نوع حساب ثانيًا ولا مسار تسجيل موازيًا.
  owner_id          uuid not null references public.merchants(id)
                      on delete cascade,

  name              text not null,
  kind              text not null,
  city              text not null,
  tagline           text not null,

  -- بالريال. صفر يعني «حسب الطلب» — وهو حال ما لا يُسعَّر بوحدة
  -- (إدارة حملة مثلًا).
  price_from        integer not null default 0,
  responds_in_hours integer,

  -- عناوين أعمال سابقة نصًّا. الصور تحتاج دلوًا وسياساتٍ ودورة حياة،
  -- وتأتي حين يوجد مزوّدون فعليون يرفعونها.
  works             text[] not null default '{}',

  status            text not null default 'pending',
  verified          boolean not null default false,

  -- سبب الرفض يُعرض للمزوّد: رفضٌ صامت يجعله يعيد التسجيل مرارًا.
  review_note       text,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint service_providers_status_valid
    check (status in ('pending', 'approved', 'rejected')),
  constraint service_providers_kind_valid
    check (kind in ('printing', 'design', 'photography', 'video',
                    'campaign', 'signage', 'giveaways')),
  constraint service_providers_price_sane
    check (price_from >= 0 and price_from <= 1000000),
  constraint service_providers_responds_sane
    check (responds_in_hours is null
           or (responds_in_hours > 0 and responds_in_hours <= 720)),
  constraint service_providers_works_bounded
    check (array_length(works, 1) is null or array_length(works, 1) <= 12),
  constraint service_providers_text_bounded
    check (length(name) between 2 and 80
           and length(city) between 2 and 40
           and length(tagline) between 10 and 200)
);

-- إدراج واحد لكل تاجر لكل صنف: تاجرٌ يسجّل مطبعته مرّتين يزاحم غيره في
-- القائمة، ولا يخدم ذلك أحدًا.
create unique index if not exists service_providers_owner_kind_uniq
  on public.service_providers (owner_id, kind);

-- الفهرس على ما يُقرأ فعلًا: المعتمَدون وحدهم، مرتّبين بالصنف والمدينة.
create index if not exists service_providers_public_idx
  on public.service_providers (kind, city)
  where status = 'approved';

alter table public.service_providers enable row level security;

-- القراءة العامّة: المعتمَدون فقط، وللجميع (التاجر يتصفّح السوق قبل أن
-- يسجّل دخوله).
drop policy if exists service_providers_read_approved on public.service_providers;
create policy service_providers_read_approved
  on public.service_providers for select
  using (status = 'approved');

-- المزوّد يرى إدراجه في كل حالاته: بلا ذلك لا يعرف أنه قيد المراجعة ولا
-- سبب رفضه، فيعيد التسجيل ويشتكي.
drop policy if exists service_providers_read_own on public.service_providers;
create policy service_providers_read_own
  on public.service_providers for select
  to authenticated
  using (owner_id = auth.uid());

drop policy if exists service_providers_insert_own on public.service_providers;
create policy service_providers_insert_own
  on public.service_providers for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists service_providers_update_own on public.service_providers;
create policy service_providers_update_own
  on public.service_providers for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists service_providers_delete_own on public.service_providers;
create policy service_providers_delete_own
  on public.service_providers for delete
  to authenticated
  using (owner_id = auth.uid());

-- المشرف يقرأ ويكتب كل شيء — بما فيه المعلَّق والمرفوض.
drop policy if exists service_providers_admin_all on public.service_providers;
create policy service_providers_admin_all
  on public.service_providers for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- الحارس: الحالة والتوثيق ليسا حقلين عاديين.
--
-- سياسة `update_own` أعلاه تسمح للمالك بتعديل صفّه، وهي لا تستطيع وحدها
-- منعه من تعديل **عمود بعينه**. بلا هذا المشغّل يستطيع أي مزوّد أن يرسل
-- `{status: 'approved', verified: true}` من أي أداة HTTP فيعتمد نفسه
-- ويوثّق نفسه — والمراجعة كلها تصير زينة.
--
-- وأي تعديل جوهري يعيد الإدراج إلى المراجعة: مزوّد يُعتمد بوصف ثم يبدّله
-- إلى غيره يكون قد تجاوز المراجعة بخطوتين.
create or replace function public.service_provider_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  new.updated_at := now();

  if tg_op = 'INSERT' then
    if not public.is_platform_admin() then
      new.status   := 'pending';
      new.verified := false;
      new.review_note := null;
    end if;
    return new;
  end if;

  if not public.is_platform_admin() then
    -- ما يملكه المشرف وحده يعود إلى قيمته السابقة مهما أُرسل.
    new.status      := old.status;
    new.verified    := old.verified;
    new.review_note := old.review_note;
    new.owner_id    := old.owner_id;

    if old.status = 'approved'
       and (new.name is distinct from old.name
            or new.kind is distinct from old.kind
            or new.city is distinct from old.city
            or new.tagline is distinct from old.tagline
            or new.price_from is distinct from old.price_from) then
      new.status := 'pending';
      new.review_note := 'أُعيد إلى المراجعة بعد تعديل جوهري';
    end if;
  end if;

  return new;
end;
$fn$;

drop trigger if exists service_provider_guard_trg on public.service_providers;
create trigger service_provider_guard_trg
  before insert or update on public.service_providers
  for each row execute function public.service_provider_guard();

-- مراجعة المشرف: دالة واحدة بدل تعديل مباشر، فيبقى القرار مسمّى ومقيّدًا
-- بالحالات الثلاث ولا يُكتب `status` بقيمة مطبعية.
create or replace function public.review_service_provider(
  p_id     uuid,
  p_status text,
  p_note   text default null,
  p_verify boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_row public.service_providers;
begin
  if not public.is_platform_admin() then
    return jsonb_build_object('ok', false, 'error', 'admin_only');
  end if;
  if p_status not in ('pending', 'approved', 'rejected') then
    return jsonb_build_object('ok', false, 'error', 'bad_status');
  end if;

  update public.service_providers
     set status      = p_status,
         review_note = p_note,
         verified    = coalesce(p_verify, verified)
   where id = p_id
  returning * into v_row;

  if v_row.id is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'id', v_row.id, 'status', v_row.status);
end;
$fn$;

revoke all on function public.review_service_provider(uuid, text, text, boolean)
  from public, anon;
grant execute on function public.review_service_provider(uuid, text, text, boolean)
  to authenticated;
