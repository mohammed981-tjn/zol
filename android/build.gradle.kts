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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
