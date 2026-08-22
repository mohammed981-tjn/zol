{{flutter_js}}
{{flutter_build_config}}

// استخدام نسخة CanvasKit المضمّنة مع التطبيق بدل CDN جوجل (gstatic)،
// حتى يعمل التطبيق أيضًا خلف الشبكات التي تحجب أو تبطئ الوصول إلى CDN.
_flutter.loader.load({
  config: { canvasKitBaseUrl: "canvaskit/" },
});
