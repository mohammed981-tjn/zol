-- مزامنة هوية العلامة.
--
-- اللون والشعار والخط تُحفظ اليوم في SharedPreferences وحدها: تضيع بضياع
-- الهاتف، ولا تتبع التاجر إلى جهاز ثانٍ، ولا تنجو من إعادة تثبيت. وهي
-- أكثر ما يجعل إعلاناته تبدو له لا لغيره — فحبسها في جهاز واحد خسارة
-- كبيرة مقابل جدول صغير.
--
-- الجهاز يبقى مصدر الحقيقة أثناء العمل: التطبيق يعمل بلا إنترنت، والسحابة
-- طبقة مزامنة لا شرط تشغيل. والتعارض يُحسم بالأحدث كتابةً — كافٍ لبيانات
-- يملكها شخص واحد ويعدّلها من جهاز واحد في الغالب.

create table if not exists public.brand_identities (
  merchant_id  uuid primary key references public.merchants(id) on delete cascade,
  color_value  integer,
  font_name    text,
  -- الشعار base64 داخل الجدول لا في Storage: أيقونة صغيرة لا تستحق
  -- دلوًا وسياساتٍ ودورة حياة. والحدّ أدناه يمنعها من أن تصير كذلك.
  logo_base64  text,
  updated_at   timestamptz not null default now(),

  constraint brand_logo_size check (
    logo_base64 is null or length(logo_base64) <= 700000
  )
);

comment on table public.brand_identities is
  'هوية علامة التاجر مزامَنةً عبر أجهزته. الجهاز مصدر الحقيقة، وهذا نسخته.';

alter table public.brand_identities enable row level security;

-- كل تاجر يرى صفّه وحده ويكتبه. لا سياسة قراءة عامة: هوية العلامة —
-- وشعارها خاصةً — ليست بيانات عامة.
create policy brand_identity_select on public.brand_identities
  for select to authenticated using (merchant_id = auth.uid());

create policy brand_identity_insert on public.brand_identities
  for insert to authenticated with check (merchant_id = auth.uid());

create policy brand_identity_update on public.brand_identities
  for update to authenticated
  using (merchant_id = auth.uid())
  with check (merchant_id = auth.uid());

create policy brand_identity_delete on public.brand_identities
  for delete to authenticated using (merchant_id = auth.uid());

-- التاريخ يُضبط في الخادم لا في العميل: ساعة الجهاز قد تكون مغلوطة،
-- وحسم التعارض بالأحدث يفسد إن كتب كل جهاز تاريخه بنفسه.
create or replace function public.brand_identity_touch()
returns trigger
language plpgsql
as $fn$
begin
  new.updated_at := now();
  return new;
end;
$fn$;

drop trigger if exists brand_identity_touch_trg on public.brand_identities;
create trigger brand_identity_touch_trg
  before insert or update on public.brand_identities
  for each row execute function public.brand_identity_touch();
