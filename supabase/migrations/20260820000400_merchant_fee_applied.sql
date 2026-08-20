-- رسم المنصّة على التاجر — **مطبَّقًا** لا محفوظًا وحده.
--
-- الترحيل السابق أضاف `merchant_fee_rate` وزرَّه، ولم يقرأه أحد:
-- `print_order_quote` و`print_order_create` تحسبان المال بلا علمٍ به.
-- فكان الزرّ يحفظ رقمًا لا أثر له — وهي علّة الحقول الميّتة نفسها التي
-- أوقعت `logo` و`tags` والهاشتاقات من قبل: قيمةٌ تُحسب في طرف ولا
-- تُقرأ في الآخر، ولا شيء يكشف الانقطاع.
--
-- **والسلوك عند صفر مطابقٌ للسابق بايتًا ببايت**: الرسم صفر، والإجمالي
-- كما كان، والضريبة كما كانت. فتطبيق هذا الترحيل لا يغيّر ما يدفعه أي
-- تاجر حتى يُضبط الرقم بيد صاحب المنصّة.
--
-- والوعاء **قيمة المنتج** لا الإجمالي: رسمٌ على رسم التوصيل يقتطع من
-- حصّة المندوب لا من قيمة الخدمة، وهو مالٌ ليس لنا فيه عمل.

alter table public.print_orders
  add column if not exists merchant_fee numeric not null default 0;

comment on column public.print_orders.merchant_fee is
  'رسم المنصّة على التاجر — نسبة من قيمة المنتج، تُضاف إلى ما يدفعه. صفر = معطّل.';

-- ── التسعيرة ────────────────────────────────────────────────────────
create or replace function public.print_order_quote(
  p_shop_id uuid,
  p_product_id uuid,
  p_quantity integer,
  p_delivery_fee numeric default 25
) returns jsonb
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_prod  public.print_products%rowtype;
  v_shop  public.print_shops%rowtype;
  v_items numeric;
  v_fee_r numeric;
  v_mfee  numeric;
  v_vat   numeric;
  v_total numeric;
  v_cut   numeric;
  v_priv  boolean;
  v_out   jsonb;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;

  select * into v_shop from public.print_shops where id = p_shop_id;
  if not found then return jsonb_build_object('ok', false, 'error', 'shop_not_found'); end if;

  -- من يرى العمولة وصافي المطبعة: الإدارة أو صاحب المطبعة نفسه فقط
  v_priv := public.is_platform_admin() or v_shop.owner_user_id = auth.uid();

  if v_shop.status <> 'approved' and not v_priv then
    return jsonb_build_object('ok', false, 'error', 'shop_not_available');
  end if;

  select * into v_prod from public.print_products
   where id = p_product_id and shop_id = p_shop_id;
  if not found then return jsonb_build_object('ok', false, 'error', 'product_not_found'); end if;
  if coalesce(v_prod.is_active, true) = false and not v_priv then
    return jsonb_build_object('ok', false, 'error', 'product_not_available');
  end if;
  if p_quantity is null or p_quantity < 1 then
    return jsonb_build_object('ok', false, 'error', 'invalid_quantity');
  end if;
  if p_quantity < v_prod.min_qty then
    return jsonb_build_object('ok', false, 'error', 'below_min_qty', 'min_qty', v_prod.min_qty);
  end if;
  if p_delivery_fee is null or p_delivery_fee < 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid_delivery_fee');
  end if;

  v_items := round(v_prod.unit_price * p_quantity, 2);
  v_fee_r := public.setting_num('merchant_fee_rate', 0);
  v_mfee  := round(v_items * v_fee_r / 100, 2);
  -- ضريبة القيمة المضافة 15% محسوبة على الإجمالي شامل التوصيل (فوترة سعودية)
  v_total := round(v_items + p_delivery_fee + v_mfee, 2);
  v_vat   := round(v_total * 0.15 / 1.15, 2);
  v_cut   := round(v_items * coalesce(v_shop.commission_rate, 15) / 100, 2);

  v_out := jsonb_build_object(
    'ok', true,
    'unit_price', v_prod.unit_price,
    'quantity', p_quantity,
    'items_total', v_items,
    'delivery_fee', p_delivery_fee,
    'merchant_fee', v_mfee,
    'vat_included', v_vat,
    'grand_total', v_total,
    'turnaround_hours', v_prod.turnaround_hours
  );

  if v_priv then
    v_out := v_out || jsonb_build_object(
      'platform_cut', v_cut,
      'platform_total', round(v_cut + v_mfee, 2),
      'shop_net', round(v_items - v_cut, 2)
    );
  end if;

  return v_out;
end;
$function$;

-- ── إنشاء الطلب ─────────────────────────────────────────────────────
create or replace function public.print_order_create(
  p_shop_id uuid,
  p_product_id uuid,
  p_quantity integer,
  p_delivery_address text default null,
  p_delivery_lat numeric default null,
  p_delivery_lng numeric default null,
  p_artwork_url text default null,
  p_artwork_notes text default null,
  p_specs jsonb default '{}'::jsonb,
  p_payment_method text default 'cash'
) returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid   uuid := auth.uid();
  v_shop  public.print_shops%rowtype;
  v_prod  public.print_products%rowtype;
  v_fee   numeric;
  v_vat_r numeric;
  v_fee_r numeric;
  v_mfee  numeric;
  v_items numeric;
  v_vat   numeric;
  v_total numeric;
  v_cut   numeric;
  v_id    uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  if p_payment_method not in ('cash','card','wallet') then
    return jsonb_build_object('ok', false, 'error', 'invalid_payment_method');
  end if;

  select * into v_shop from public.print_shops where id = p_shop_id;
  if not found or v_shop.status <> 'approved' or not coalesce(v_shop.is_open, true) then
    return jsonb_build_object('ok', false, 'error', 'shop_not_available');
  end if;

  select * into v_prod from public.print_products
   where id = p_product_id and shop_id = p_shop_id;
  if not found or not coalesce(v_prod.is_active, true) then
    return jsonb_build_object('ok', false, 'error', 'product_not_available');
  end if;

  if p_quantity is null or p_quantity < 1 then
    return jsonb_build_object('ok', false, 'error', 'invalid_quantity');
  end if;
  if p_quantity < v_prod.min_qty then
    return jsonb_build_object('ok', false, 'error', 'below_min_qty', 'min_qty', v_prod.min_qty);
  end if;
  if p_quantity > 1000000 then
    return jsonb_build_object('ok', false, 'error', 'quantity_too_large');
  end if;

  -- المال يُحسب هنا وحده. لا يصل من العميل شيء منه.
  v_fee   := public.setting_num('delivery_fee', 25);
  v_vat_r := public.setting_num('vat_rate', 0.15);
  v_fee_r := public.setting_num('merchant_fee_rate', 0);
  v_items := round(v_prod.unit_price * p_quantity, 2);
  v_mfee  := round(v_items * v_fee_r / 100, 2);
  v_total := round(v_items + v_fee + v_mfee, 2);
  v_vat   := round(v_total * v_vat_r / (1 + v_vat_r), 2);
  v_cut   := round(v_items * coalesce(v_shop.commission_rate, 15) / 100, 2);

  insert into public.print_orders (
    merchant_id, shop_id, product_kind, quantity, specs,
    artwork_url, artwork_notes, status,
    items_total, delivery_fee, merchant_fee, vat_amount, grand_total, platform_cut,
    payment_method, delivery_address, delivery_lat, delivery_lng, promised_at
  ) values (
    v_uid, p_shop_id, v_prod.kind, p_quantity, coalesce(p_specs, '{}'::jsonb),
    p_artwork_url, p_artwork_notes, 'submitted',
    v_items, v_fee, v_mfee, v_vat, v_total, v_cut,
    p_payment_method, p_delivery_address, p_delivery_lat, p_delivery_lng,
    now() + make_interval(hours => coalesce(v_prod.turnaround_hours, 24))
  ) returning id into v_id;

  insert into public.print_order_events (order_id, from_status, to_status, actor_id, actor_role, note)
  values (v_id, null, 'submitted', v_uid, 'merchant', 'إنشاء الطلب');

  return jsonb_build_object(
    'ok', true, 'order_id', v_id,
    'items_total', v_items, 'delivery_fee', v_fee,
    'merchant_fee', v_mfee,
    'vat_included', v_vat, 'grand_total', v_total,
    'turnaround_hours', v_prod.turnaround_hours
  );
end; $function$;
