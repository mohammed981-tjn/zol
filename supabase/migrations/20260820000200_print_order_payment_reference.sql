-- مرجع عملية الدفع على الطلب.
--
-- الطلب يحمل `payment_method` و`is_paid` ولا يحمل **رقم العملية**. فبطاقة
-- تُقبض في ميسر وطلبٌ يُسجَّل هنا لا رابط بينهما: لا مطابقة دفاتر، ولا
-- استرداد يُنسب إلى طلبه، ولا إثبات دفعٍ حين ينكر أحد الطرفين.
alter table public.print_orders
  add column if not exists payment_ref text;

comment on column public.print_orders.payment_ref is
  'معرّف العملية لدى بوابة الدفع. مرجعٌ للمطابقة لا إثباتُ دفع — is_paid يضبطه الخادم.';

/*
 * يربط الطلب بعملية الدفع، ولا يعلن الدفع.
 *
 * الفصل مقصود: `is_paid` **لا يُلمَس هنا**. قاعدة المشروع أن الخادم لا
 * يصدّق ادّعاء التطبيق أن الدفع تمّ — من يستطيع أن يقول «دفعتُ» يستطيع
 * أن يكذب. فيُسجَّل المرجع ليطابقه لاحقًا webhook البوابة أو الإدارة،
 * ويبقى الطلب غير مدفوع حتى يؤكّده من يملك التأكيد.
 *
 * والتاجر يربط طلبه هو وحده، ومرّةً واحدة: مرجعٌ ثانٍ فوق الأول يمحو
 * أثر عملية قد تكون هي الصحيحة.
 */
create or replace function public.print_order_attach_payment(
  p_order_id uuid,
  p_payment_ref text
) returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
declare
  v_uid uuid := auth.uid();
  v_ord public.print_orders%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  if coalesce(btrim(p_payment_ref), '') = '' then
    return jsonb_build_object('ok', false, 'error', 'payment_ref_required');
  end if;

  select * into v_ord from public.print_orders where id = p_order_id;
  if not found or v_ord.merchant_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'order_not_found');
  end if;
  if v_ord.payment_ref is not null then
    return jsonb_build_object('ok', false, 'error', 'already_attached');
  end if;

  update public.print_orders
     set payment_ref = btrim(p_payment_ref), updated_at = now()
   where id = p_order_id;

  return jsonb_build_object('ok', true, 'order_id', p_order_id);
end; $fn$;

revoke all on function public.print_order_attach_payment(uuid, text) from public;
grant execute on function public.print_order_attach_payment(uuid, text) to authenticated;
