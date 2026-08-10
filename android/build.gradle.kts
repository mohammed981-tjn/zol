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
// محاولتان سابقتان فشلتا: التوحيد المباشر في subprojects{} ينفَّذ أثناء
// تقييم الجذر — أي قبل أن تبدأ كل وحدة فرعية تقييم سكربتها الخاص أصلاً —
// فيُسجَّل كأول عنصر في طابور afterEvaluate، فينفَّذ أولًا، ويكسبه AGP
// بتسجيله المتأخر (من داخل سكربت الإضافة نفسه) الذي يُنفَّذ بعده مباشرة.
// gradle.projectsEvaluated{} هو الحل الصحيح: خطّاف على مستوى البناء كله
// يعمل فقط بعد اكتمال تقييم كل المشاريع (بما فيها كل afterEvaluate لكل
// مشروع)، فيضمن أن توحيدنا هو آخر ما يُطبَّق فعليًا.
gradle.projectsEvaluated {
    rootProject.subprojects {
        if (name == "app") return@subprojects
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
