allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// بعض إضافات الطرف الثالث (مثل pay_android) تحدد إعدادات JVM قديمة/متضاربة
// بين مهام Java وKotlin الخاصة بها، وهو ما يفشّل البناء تحت AGP 9. توحيدها
// هنا لكل الوحدات الفرعية يحل التعارض دون المساس بإعداد وحدة app نفسها.
//
// ثلاث محاولات سابقتان فشلتا كلها بإعادة كتابة خواص مهام JavaCompile/
// KotlinCompile مباشرة (tasks.withType) — إما مبكرًا فيكسبها تسجيل AGP
// المتأخر، أو عبر gradle.projectsEvaluated{} بعد اكتمال كل التقييم، وهو
// ما وحّد فعلًا هدف JVM لكن كسر classpath الترجمة (فقدت geolocator_android
// إمكانية الوصول لحزم android.* لأن إعادة كتابة الخاصية بعد اكتمال تهيئة
// AGP لا تُعيد ربط classpath الخاص بها).
//
// الحل الصحيح: الإعداد عبر DSL نفسه (compileOptions / kotlin{}) لحظة تطبيق
// الإضافة — عبر plugins.withId، الذي يُطلَق فعليًا في لحظة apply() لكل
// وحدة فرعية (لا وقت تقييم الجذر) — فتقرأ AGP قيمتنا أثناء بنائها الطبيعي
// لمهام الترجمة بدل أن نُعيد كتابتها لاحقًا فوق ما بنته.
subprojects {
    if (name == "app") return@subprojects
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    plugins.withId("org.jetbrains.kotlin.android") {
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

// النتيجة بعد التوحيد عبر DSL أعلاه: نجح جانب Java (compileOptions) بلا
// أي كسر لـ classpath — لكن pay_android يحدد kotlinOptions.jvmTarget="1.8"
// صراحةً داخل سكربتها الخاص (سطر متأخر في ملفها)، فيُنفَّذ بعد withId
// المبكر أعلاه ويكسبه. لا حل إلا تطبيق الهدف بعد اكتمال كل تقييم فعليًا.
// نقصر هذا على مهام Kotlin فقط (لا Java) لأن كسر classpath السابق كان في
// javac تحديدًا (geolocator فقدت android.*)، ولم يظهر أي كسر مشابه في
// جانب Kotlin عند اختباره — فالمهمتان غير متكافئتين هنا في الأمان.
gradle.projectsEvaluated {
    rootProject.subprojects {
        if (name == "app") return@subprojects
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
