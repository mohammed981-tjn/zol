-- إحداثيات المطبعة.
--
-- التوجيه التلقائي في التطبيق يختار «الأقرب» بمسافة هافرساين، والجدول
-- الحقيقي بلا إحداثيات — فالتوجيه كان يعمل على قائمة محلية محفورة ولا
-- سبيل له إلى مطبعة حقيقية. وبلا هذين العمودين يبقى الخادم عاجزًا عن
-- الإسناد الذي يَعِد به التطبيق.
--
-- ويبقيان اختياريين: مطبعة تُسجَّل بلا موقع تظهر في الدليل ولا تدخل
-- حساب الأقرب، وهذا أصحّ من إجبار حقلٍ قد لا يعرفه صاحبها وقت التسجيل.
alter table public.print_shops
  add column if not exists lat double precision,
  add column if not exists lng double precision;

comment on column public.print_shops.lat is
  'خط العرض — يدخل حساب أقرب مطبعة. فارغ يعني: تظهر ولا تُسنَد تلقائيًا.';
comment on column public.print_shops.lng is
  'خط الطول — انظر lat.';

-- فهرس جزئي: الاستعلام الوحيد الذي يمسّهما هو «المعتمَدة التي لها موقع».
create index if not exists print_shops_located_idx
  on public.print_shops (status)
  where lat is not null and lng is not null;
