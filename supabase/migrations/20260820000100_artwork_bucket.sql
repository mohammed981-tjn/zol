-- سطل ملفّات التصميم المطلوب طباعتها.
--
-- كان الطلب يصل المطبعة — لو وصل — بلا ما تطبعه: لا عمود ملفّ في
-- الطلب يُملأ، ولا سبيل للتطبيق أن يرفع شيئًا أصلًا. فـ`storage.objects`
-- عليه RLS بلا **أي** سياسة، ومعنى ذلك المنع التامّ: كل رفع من التطبيق
-- يُردّ، ولهذا ترفع دوالّ الحافة بمفتاح الخدمة من الخادم.
--
-- وسطل مستقلّ لا `ads`: ذاك مخرَجات الذكاء المؤقّتة، وهذا **مستند
-- إنتاج** تطبعه مطبعة على ورق. خلطهما يجعل تنظيف الأول يمحو الثاني.
insert into storage.buckets (id, name, public)
values ('artwork', 'artwork', true)
on conflict (id) do nothing;

-- القراءة عامّة: المطبعة تفتح الملفّ من لوحة ويب ساكنة بمفتاح منشور،
-- ولا جلسة لها في سياق الصورة. والمحتوى إعلانٌ يقصد صاحبه نشره.
drop policy if exists artwork_read on storage.objects;
create policy artwork_read on storage.objects
  for select using (bucket_id = 'artwork');

-- والكتابة في مجلّد صاحبها وحده. `foldername(name)[1]` أول مقطع في
-- المسار، فالتاجر يكتب تحت `<uid>/` ولا يكتب تحت غيره — وبدون هذا
-- الشرط يستطيع أي تاجر استبدال تصميم تاجر آخر قبل أن يُطبع.
drop policy if exists artwork_write_own on storage.objects;
create policy artwork_write_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'artwork'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists artwork_update_own on storage.objects;
create policy artwork_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'artwork'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists artwork_delete_own on storage.objects;
create policy artwork_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'artwork'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
