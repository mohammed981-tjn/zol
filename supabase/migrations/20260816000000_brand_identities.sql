-- مزامنة هوية العلامة.
--
-- اللون والشعار والخط كانت في SharedPreferences وحدها: تضيع بضياع الهاتف،
-- ولا تتبع التاجر إلى جهاز ثانٍ، ولا تنجو من إعادة تثبيت.
--
-- ⚠️ الجدول كان موجودًا مسبقًا على zol-adcraft بمخطط مختلف عمّا افترضته
-- (primary_color نصًّا لا color_value رقمًا، ولا عمود للخط، ومفتاحه id لا
-- merchant_id). فهذا الترحيل **توفيقيّ**: يضيف الناقص ولا يفرض مخططًا
-- موازيًا. عمودان للون واحد يعني مصدرَي حقيقة يتباعدان.

alter table public.brand_identities
  add column if not exists font_name   text,
  add column if not exists logo_base64 text;

-- الشعار داخل الجدول لا في Storage: أيقونة صغيرة لا تستحق دلوًا وسياساتٍ
-- ودورة حياة. والقيد يمنعها من أن تصير كذلك.
alter table public.brand_identities
  drop constraint if exists brand_logo_size;
alter table public.brand_identities
  add constraint brand_logo_size check (
    logo_base64 is null or length(logo_base64) <= 700000
  );

-- هوية واحدة لكل تاجر. ضروري لـupsert على merchant_id، وصحيح دلاليًا:
-- هويتان لتاجر واحد تعني أن إحداهما مهجورة بلا أن يعرف أحد أيّهما.
alter table public.brand_identities
  drop constraint if exists brand_identities_merchant_unique;
alter table public.brand_identities
  add constraint brand_identities_merchant_unique unique (merchant_id);

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

-- السياستان القائمتان brand_identities_select_own و _write_own تغطّيان كل
-- الأوامر بشرط auth.uid() = merchant_id، فلا حاجة لغيرهما.
