# لوحة إدارة AdCraft — حزمة النشر على Vercel

`index.html` (اللوحة كاملة، بلا بناء) و`vercel.json` (ترويسات أمان)،
و`supabase.js` + `591.supabase.js` (مكتبة supabase-js 2.45.4 نسخة UMD
محفوظة محليًا بدل CDN — فلا تتوقف اللوحة لو حُجب jsdelivr أو كانت الشبكة
مقيّدة). لا اعتماديات npm ولا خطوة بناء إطلاقًا.

> المكتبة تُحمَّل عبر `<script src="./supabase.js">` ولا تُلصَق داخل
> `index.html` نفسه: webpack يشتق `publicPath` من `document.currentScript.src`،
> فالسكربت المضمَّن بلا `src` يرمي «Automatic publicPath is not supported».

## النشر
هذه الحزمة داخل مستودع zol في مجلد `vercel-adcraft/`.
1. Vercel → Add New → Project → استورد `mohammed981-tjn/zol`.
2. **Root Directory: `vercel-adcraft`** ← الخطوة المهمة.
3. Framework Preset: **Other**. اترك أمر البناء ومجلد الإخراج فارغين.
4. Deploy.

## التبويبات
لوحة القيادة · الطلبات · المطابع · المناديب · **التوليد** (سجل ما ولّده الذكاء:
النصوص الثلاثة بدرجاتها، الصورة أو الفيديو، التكلفة بالريال، والنص المعدَّل بيد التاجر).

## الأمان
الصفحة تحمل المفتاح العام (publishable) فقط، وهو مصمَّم للمتصفح.
كل الحماية في القاعدة: RLS + فحص is_platform_admin() داخل كل دالة. لا مفتاح سري هنا.
