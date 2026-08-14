import { buildProvidersFromEnv, createApp } from './app.ts';

const port = Number(process.env.PORT ?? 8080);

const { textProvider, imageProvider, mock } = buildProvidersFromEnv();
const app = createApp({ textProvider, imageProvider });

app.listen(port, () => {
  const image = imageProvider ? imageProvider.name : 'معطّل (نص فقط)';
  const mode = mock
    ? 'MOCK (بلا مفاتيح وبلا تكلفة)'
    : `حقيقي — نص: ${textProvider.name} · صورة: ${image}`;
  console.log(`منسّق AdCraft يعمل على المنفذ ${port} — الوضع: ${mode}`);
});
