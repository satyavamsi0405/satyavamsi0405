#!/usr/bin/env bash
set -e
mkdir -p app/src/main/java/com/quickmath/sprint app/src/main/res/values .github/workflows gradle/wrapper

cat > "settings.gradle.kts" <<'QMS_EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "QuickMathSprint"
include(":app")
QMS_EOF

cat > "build.gradle.kts" <<'QMS_EOF'
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}
QMS_EOF

cat > "gradle.properties" <<'QMS_EOF'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
QMS_EOF

cat > "app/build.gradle.kts" <<'QMS_EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.quickmath.sprint"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.quickmath.sprint"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
QMS_EOF

cat > "app/src/main/AndroidManifest.xml" <<'QMS_EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <application
        android:allowBackup="true"
        android:label="@string/app_name"
        android:icon="@android:drawable/sym_def_app_icon"
        android:theme="@style/Theme.QuickMathSprint">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:screenOrientation="portrait"
            android:theme="@style/Theme.QuickMathSprint">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
QMS_EOF

cat > "app/src/main/res/values/strings.xml" <<'QMS_EOF'
<resources>
    <string name="app_name">Quick Math Sprint</string>
</resources>
QMS_EOF

cat > "app/src/main/res/values/themes.xml" <<'QMS_EOF'
<resources>
    <style name="Theme.QuickMathSprint" parent="android:Theme.Material.NoActionBar">
        <item name="android:statusBarColor">#121821</item>
        <item name="android:windowBackground">#121821</item>
    </style>
</resources>
QMS_EOF

cat > "app/src/main/java/com/quickmath/sprint/MainActivity.kt" <<'QMS_EOF'
package com.quickmath.sprint

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlin.math.max
import kotlin.random.Random

// ---------- Theme colors (mirrors the original web prototype) ----------

val Bg = Color(0xFF121821)
val Surface = Color(0xFF1A222C)
val SurfaceAlt = Color(0xFF212B37)
val LineColor = Color(0xFF2C3644)
val Amber = Color(0xFFFFB238)
val Green = Color(0xFF6FCF97)
val Red = Color(0xFFE8604C)
val TextMain = Color(0xFFE9EDF2)
val Muted = Color(0xFF8494A3)

// ---------- Domain model ----------

data class LevelDef(val id: Int, val digitLabel: String, val title: String, val desc: String)

val LEVELS = listOf(
    LevelDef(1, "1", "Single digits", "1-9, + \u2212 \u00D7"),
    LevelDef(2, "2", "Double digits", "10-99, + \u2212 \u00D7"),
    LevelDef(3, "3", "Triple digits", "100-999, + \u2212"),
    LevelDef(4, "\u221E", "Mixed bag", "random mix of all sizes"),
)

val DURATIONS = listOf(30, 60, 120)

enum class Screen { HOME, COUNTDOWN, GAME, RESULTS }

data class Problem(val text: String, val answer: Int)

fun generateProblem(level: LevelDef): Problem {
    val digitTier = if (level.id == 4) listOf(1, 2, 3).random() else level.id
    val ops = if (digitTier == 3) listOf('+', '-') else listOf('+', '-', '*')
    val op = ops.random()
    var a: Int
    var b: Int
    when (digitTier) {
        1 -> {
            a = Random.nextInt(1, 10)
            b = Random.nextInt(1, 10)
        }
        2 -> {
            if (op == '*') {
                a = Random.nextInt(10, 100)
                b = Random.nextInt(2, 10)
            } else {
                a = Random.nextInt(10, 100)
                b = Random.nextInt(10, 100)
            }
        }
        else -> {
            a = Random.nextInt(100, 1000)
            b = Random.nextInt(100, 1000)
        }
    }
    if (op == '-' && a < b) {
        val t = a; a = b; b = t
    }
    val answer = when (op) {
        '+' -> a + b
        '-' -> a - b
        else -> a * b
    }
    val symbol = if (op == '*') "\u00D7" else op.toString()
    return Problem("$a $symbol $b", answer)
}

// ---------- Persistence (best score per level) ----------

fun loadBest(context: Context, levelId: Int): Int? {
    val prefs = context.getSharedPreferences("quickmath", Context.MODE_PRIVATE)
    val v = prefs.getInt("best_$levelId", -1)
    return if (v >= 0) v else null
}

fun saveBest(context: Context, levelId: Int, score: Int) {
    val prefs = context.getSharedPreferences("quickmath", Context.MODE_PRIVATE)
    prefs.edit().putInt("best_$levelId", score).apply()
}

// ---------- Activity ----------

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(
                colorScheme = darkColorScheme(
                    background = Bg,
                    surface = Surface,
                    primary = Amber,
                    onBackground = TextMain,
                    onSurface = TextMain,
                )
            ) {
                Surface(color = Bg, modifier = Modifier.fillMaxSize()) {
                    AppRoot()
                }
            }
        }
    }
}

// ---------- Root composable / state machine ----------

@Composable
fun AppRoot() {
    val context = LocalContext.current

    var screen by remember { mutableStateOf(Screen.HOME) }
    var selectedLevel by remember { mutableStateOf(LEVELS[0]) }
    var duration by remember { mutableIntStateOf(60) }

    var bestScores by remember {
        mutableStateOf(LEVELS.associate { it.id to loadBest(context, it.id) })
    }

    // Round state
    var score by remember { mutableIntStateOf(0) }
    var wrong by remember { mutableIntStateOf(0) }
    var streak by remember { mutableIntStateOf(0) }
    var bestStreak by remember { mutableIntStateOf(0) }
    var answerTimes by remember { mutableStateOf(listOf<Long>()) }
    var timeLeft by remember { mutableIntStateOf(60) }
    var currentProblem by remember { mutableStateOf(generateProblem(LEVELS[0])) }
    var questionStartMs by remember { mutableLongStateOf(0L) }
    var input by remember { mutableStateOf("") }
    var flashState by remember { mutableStateOf(0) } // 0 none, 1 correct, -1 wrong
    var lastFeedback by remember { mutableStateOf("") }
    var newBest by remember { mutableStateOf(false) }

    fun startRound() {
        score = 0; wrong = 0; streak = 0; bestStreak = 0
        answerTimes = emptyList()
        timeLeft = duration
        currentProblem = generateProblem(selectedLevel)
        questionStartMs = System.currentTimeMillis()
        input = ""
        flashState = 0
        lastFeedback = ""
        screen = Screen.GAME
    }

    fun submitAnswer() {
        if (screen != Screen.GAME) return
        val given = input.trim().toIntOrNull() ?: return
        val elapsed = System.currentTimeMillis() - questionStartMs
        answerTimes = answerTimes + elapsed

        if (given == currentProblem.answer) {
            score += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            flashState = 1
            lastFeedback = if (streak >= 3) "$streak in a row" else ""
        } else {
            wrong += 1
            streak = 0
            flashState = -1
            lastFeedback = "answer was ${currentProblem.answer}"
        }

        currentProblem = generateProblem(selectedLevel)
        questionStartMs = System.currentTimeMillis()
        input = ""
    }

    fun finishRound() {
        val prev = bestScores[selectedLevel.id]
        if (prev == null || score > prev) {
            newBest = true
            saveBest(context, selectedLevel.id, score)
            bestScores = bestScores.toMutableMap().also { it[selectedLevel.id] = score }
        } else {
            newBest = false
        }
        screen = Screen.RESULTS
    }

    // Countdown timer
    LaunchedEffect(screen) {
        if (screen == Screen.COUNTDOWN) {
            // handled inside CountdownScreen
        }
    }

    // Game round ticking
    LaunchedEffect(screen, duration) {
        if (screen == Screen.GAME) {
            while (timeLeft > 0 && screen == Screen.GAME) {
                delay(1000)
                timeLeft -= 1
            }
            if (screen == Screen.GAME) finishRound()
        }
    }

    // Clear the flash highlight shortly after each answer
    LaunchedEffect(flashState) {
        if (flashState != 0) {
            delay(250)
            flashState = 0
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 18.dp, vertical = 24.dp)
    ) {
        when (screen) {
            Screen.HOME -> HomeScreen(
                bestScores = bestScores,
                duration = duration,
                onSelectLevel = { level ->
                    selectedLevel = level
                    screen = Screen.COUNTDOWN
                },
                onSelectDuration = { duration = it },
            )
            Screen.COUNTDOWN -> CountdownScreen(
                levelName = selectedLevel.title,
                onDone = { startRound() },
            )
            Screen.GAME -> GameScreen(
                duration = duration,
                timeLeft = timeLeft,
                score = score,
                streak = streak,
                problem = currentProblem,
                input = input,
                onInputChange = { input = it },
                onSubmit = { submitAnswer() },
                flashState = flashState,
                feedback = lastFeedback,
            )
            Screen.RESULTS -> ResultsScreen(
                level = selectedLevel,
                duration = duration,
                score = score,
                wrong = wrong,
                bestStreak = bestStreak,
                answerTimesMs = answerTimes,
                isNewBest = newBest,
                onChangeLevel = { screen = Screen.HOME },
                onPlayAgain = { screen = Screen.COUNTDOWN },
            )
        }
    }
}

// ---------- Home ----------

@Composable
fun HomeScreen(
    bestScores: Map<Int, Int?>,
    duration: Int,
    onSelectLevel: (LevelDef) -> Unit,
    onSelectDuration: (Int) -> Unit,
) {
    Column {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Bottom,
        ) {
            Text(
                text = "Quick Math Sprint",
                color = TextMain,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        Text(
            text = "pick a level",
            color = Muted,
            fontSize = 12.sp,
            modifier = Modifier.padding(bottom = 20.dp, top = 2.dp)
        )

        LEVELS.forEach { level ->
            LevelRow(
                level = level,
                best = bestScores[level.id],
                onClick = { onSelectLevel(level) },
            )
            Spacer(modifier = Modifier.height(10.dp))
        }

        Spacer(modifier = Modifier.height(14.dp))
        Divider(color = LineColor)
        Spacer(modifier = Modifier.height(14.dp))

        Text(text = "round length", color = Muted, fontSize = 12.sp)
        Spacer(modifier = Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            DURATIONS.forEach { d ->
                val active = d == duration
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .border(
                            width = 1.dp,
                            color = if (active) Amber else LineColor,
                            shape = RoundedCornerShape(8.dp)
                        )
                        .background(Surface, RoundedCornerShape(8.dp))
                        .clickable { onSelectDuration(d) }
                        .padding(vertical = 10.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "${d}s",
                        color = if (active) Amber else Muted,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                    )
                }
            }
        }
    }
}

@Composable
fun LevelRow(level: LevelDef, best: Int?, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, LineColor, RoundedCornerShape(10.dp))
            .background(Surface, RoundedCornerShape(10.dp))
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = level.digitLabel,
            color = Amber,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            fontSize = 22.sp,
            modifier = Modifier.width(34.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(text = level.title, color = TextMain, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Text(text = level.desc, color = Muted, fontSize = 12.sp)
        }
        Text(
            text = if (best != null) "best $best" else "no runs yet",
            color = if (best != null) Green else Muted,
            fontFamily = FontFamily.Monospace,
            fontSize = 12.sp,
        )
    }
}

// ---------- Countdown ----------

@Composable
fun CountdownScreen(levelName: String, onDone: () -> Unit) {
    var n by remember { mutableIntStateOf(3) }

    LaunchedEffect(Unit) {
        n = 3
        while (n > 0) {
            delay(700)
            n -= 1
        }
        onDone()
    }

    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = if (n > 0) n.toString() else "Go",
            color = Amber,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            fontSize = 88.sp,
        )
        Spacer(modifier = Modifier.height(6.dp))
        Text(text = levelName, color = Muted, fontSize = 14.sp)
    }
}

// ---------- Game ----------

@Composable
fun GameScreen(
    duration: Int,
    timeLeft: Int,
    score: Int,
    streak: Int,
    problem: Problem,
    input: String,
    onInputChange: (String) -> Unit,
    onSubmit: () -> Unit,
    flashState: Int,
    feedback: String,
) {
    val pct = max(timeLeft, 0).toFloat() / duration.toFloat()
    val trackColor = if (timeLeft <= duration * 0.2) Red else Amber
    val cardBorder = when (flashState) {
        1 -> Green
        -1 -> Red
        else -> LineColor
    }

    Column {
        // Timer bar
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .background(SurfaceAlt, RoundedCornerShape(3.dp))
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(pct)
                    .fillMaxHeight()
                    .background(trackColor, RoundedCornerShape(3.dp))
            )
        }
        Spacer(modifier = Modifier.height(10.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            MetaStat("score", score.toString())
            MetaStat("streak", streak.toString())
            MetaStat("time", "${max(timeLeft, 0)}s")
        }

        Spacer(modifier = Modifier.height(26.dp))

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, cardBorder, RoundedCornerShape(14.dp))
                .background(Surface, RoundedCornerShape(14.dp))
                .padding(vertical = 40.dp, horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = problem.text,
                color = TextMain,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                fontSize = 40.sp,
            )
        }

        Spacer(modifier = Modifier.height(18.dp))

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = input,
                onValueChange = { new -> if (new.length <= 6) onInputChange(new.filter { it.isDigit() || it == '-' }) },
                modifier = Modifier.weight(1f),
                placeholder = { Text("?", color = Muted) },
                textStyle = androidx.compose.ui.text.TextStyle(
                    fontFamily = FontFamily.Monospace,
                    fontSize = 22.sp,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    color = TextMain,
                ),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Amber,
                    unfocusedBorderColor = LineColor,
                    focusedContainerColor = Surface,
                    unfocusedContainerColor = Surface,
                ),
                singleLine = true,
            )
            Button(
                onClick = onSubmit,
                colors = ButtonDefaults.buttonColors(containerColor = Amber, contentColor = Color(0xFF14181F)),
                shape = RoundedCornerShape(10.dp),
                modifier = Modifier.height(56.dp),
            ) {
                Text("Go", fontWeight = FontWeight.Bold)
            }
        }

        Spacer(modifier = Modifier.height(14.dp))
        Text(
            text = feedback,
            color = if (streak >= 3) Amber else Muted,
            fontSize = 12.sp,
            modifier = Modifier.fillMaxWidth(),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
    }
}

@Composable
fun MetaStat(label: String, value: String) {
    Row {
        Text(text = "$label ", color = Muted, fontSize = 12.sp)
        Text(text = value, color = TextMain, fontFamily = FontFamily.Monospace, fontSize = 12.sp, fontWeight = FontWeight.Bold)
    }
}

// ---------- Results ----------

@Composable
fun ResultsScreen(
    level: LevelDef,
    duration: Int,
    score: Int,
    wrong: Int,
    bestStreak: Int,
    answerTimesMs: List<Long>,
    isNewBest: Boolean,
    onChangeLevel: () -> Unit,
    onPlayAgain: () -> Unit,
) {
    val total = score + wrong
    val accuracy = if (total > 0) (score * 100 / total) else 0
    val avgTimeSec = if (answerTimesMs.isNotEmpty()) {
        (answerTimesMs.sum().toDouble() / answerTimesMs.size) / 1000.0
    } else 0.0

    Column {
        Text(text = level.title, color = TextMain, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Text(
            text = "${duration}s round \u00B7 ${level.desc}",
            color = Muted,
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 2.dp, bottom = 18.dp)
        )

        if (isNewBest) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, Green, RoundedCornerShape(8.dp))
                    .background(Green.copy(alpha = 0.12f), RoundedCornerShape(8.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                Text("New best on this level", color = Green, fontSize = 13.sp)
            }
            Spacer(modifier = Modifier.height(18.dp))
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, LineColor, RoundedCornerShape(10.dp))
        ) {
            Row(modifier = Modifier.fillMaxWidth()) {
                StatCell("correct", score.toString(), Green, Modifier.weight(1f))
                StatCell("wrong", wrong.toString(), Red, Modifier.weight(1f))
            }
            Divider(color = LineColor)
            Row(modifier = Modifier.fillMaxWidth()) {
                StatCell("accuracy", "$accuracy%", Amber, Modifier.weight(1f))
                StatCell("avg time / answer", String.format("%.1fs", avgTimeSec), TextMain, Modifier.weight(1f))
            }
            Divider(color = LineColor)
            Row(modifier = Modifier.fillMaxWidth()) {
                StatCell("best streak", bestStreak.toString(), TextMain, Modifier.weight(1f))
                StatCell("questions seen", total.toString(), TextMain, Modifier.weight(1f))
            }
        }

        Spacer(modifier = Modifier.height(22.dp))

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton(
                onClick = onChangeLevel,
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(10.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, LineColor),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = TextMain),
            ) {
                Text("Change level")
            }
            Button(
                onClick = onPlayAgain,
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Amber, contentColor = Color(0xFF14181F)),
            ) {
                Text("Play again", fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun StatCell(label: String, value: String, color: Color, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .background(Surface)
            .padding(16.dp)
    ) {
        Text(text = value, color = color, fontFamily = FontFamily.Monospace, fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(4.dp))
        Text(text = label, color = Muted, fontSize = 12.sp)
    }
}
QMS_EOF

cat > "README.md" <<'QMS_EOF'
# Quick Math Sprint (Android)

A native Android app (Kotlin + Jetpack Compose) for timed mental-math drills:
single digit → double digit → triple digit → mixed, with a countdown round
timer and an end-of-round stats screen. Best score per level is saved on
device (SharedPreferences), so it persists between sessions.

## How to build it

### Option A — Android Studio (needs a computer)

1. Install [Android Studio](https://developer.android.com/studio) (free).
2. `File → Open`, select this `QuickMathSprint` folder.
3. Let Gradle sync (first sync downloads the Android Gradle Plugin, Kotlin,
   and Compose libraries — needs internet once).
4. Press ▶ Run with an emulator or a phone connected via USB debugging.

No manual setup beyond that — minSdk 24 (Android 7.0+), targetSdk 34.

### Option B — build the APK in the cloud (phone only, no computer)

This project includes `.github/workflows/build.yml`, which builds a debug
APK on GitHub's servers whenever you push. All you need is a phone and the
GitHub app (or mobile browser).

1. On github.com (or the GitHub mobile app), create a new empty repository,
   e.g. `quick-math-sprint`.
2. Get this project's files into that repo. Easiest from a phone: in the
   GitHub app / web UI use "Add file → Upload files" and upload the
   contents of this folder (keep the folder structure — `app/`, `.github/`,
   etc. all need to land at the repo root).
3. Once pushed, go to the repo's **Actions** tab. The "Build debug APK"
   workflow runs automatically on push (or tap "Run workflow" to trigger it
   by hand).
4. When it finishes (green check, a couple of minutes), open that run and
   download the **QuickMathSprint-debug-apk** artifact — it's a zip
   containing `app-debug.apk`.
5. On your Android phone: unzip it (any file manager/zip app handles this),
   tap `app-debug.apk`, and allow "install unknown apps" for that app if
   prompted. It installs like any other app.

No Android SDK, no Gradle install, no laptop — GitHub's runner has
everything preinstalled.

## Project layout

- `app/src/main/java/com/quickmath/sprint/MainActivity.kt` — the entire app:
  screens (Home → Countdown → Game → Results), problem generation, timer
  logic, and score persistence.
- `app/src/main/AndroidManifest.xml`, `res/values/` — manifest and minimal
  resources (Compose draws everything else in code).

## Levels

| Level | Range | Operations |
|---|---|---|
| Single digits | 1–9 | + − × |
| Double digits | 10–99 | + − ×  (× keeps one factor 2–9) |
| Triple digits | 100–999 | + − |
| Mixed bag | random mix of the above | + − × |

Subtraction always keeps the answer non-negative (larger operand first).

## Customizing

- Round lengths: edit `DURATIONS` in `MainActivity.kt`.
- Add a level (e.g. division): add an entry to `LEVELS` and extend
  `generateProblem()`.
- Colors/theme: top of `MainActivity.kt` (`Bg`, `Amber`, `Green`, etc.).
QMS_EOF

cat > ".gitignore" <<'QMS_EOF'
*.iml
.gradle
/local.properties
/.idea
.DS_Store
/build
/captures
.externalNativeBuild
.cxx
local.properties
/app/build
QMS_EOF

cat > ".github/workflows/build.yml" <<'QMS_EOF'
name: Build debug APK

on:
  push:
    branches: [ main, master ]
  workflow_dispatch: {}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Set up Gradle
        uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: '8.7'

      - name: Build debug APK
        run: gradle assembleDebug

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: QuickMathSprint-debug-apk
          path: app/build/outputs/apk/debug/app-debug.apk
QMS_EOF

git add -A
git commit -m "Initial commit"
git push
