-- مرشّحو الشراكة: حسابات التجّار التي لم تُربط بشريك بعد.
--
-- إنشاء الشريك يحتاج `merchant_id`، وجعل المشرف ينسخ UUID يدويًا من
-- القاعدة يعني أن كل شريك جديد يمرّ بمن يملك وصولًا للقاعدة — وهو ما
-- بُنيت لوحة الإدارة أصلًا لتفاديه. هذه الدالة تحوّله إلى اختيار من قائمة.
--
-- تستبعد المرتبطين مسبقًا: تاجر واحد لشريكين يخلط استهلاكهما فتنهار
-- المحاسبة والحصص معًا.

create or replace function public.partner_candidate_merchants()
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
             'id', m.id,
             'name', coalesce(nullif(m.business_name, ''), 'تاجر بلا اسم'),
             'category', m.category)
           order by m.created_at desc)
    from public.merchants m
    where not exists (
      select 1 from public.partners p where p.merchant_id = m.id
    )
  ), '[]'::jsonb));
end;
$fn$;

grant execute on function public.partner_candidate_merchants() to authenticated;
