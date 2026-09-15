#!/usr/bin/env bash
set -e

cat > "app/src/main/java/com/quickmath/sprint/MainActivity.kt" <<'QMS_EOF'
package com.quickmath.sprint

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min

// ---------- Theme colors ----------

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

enum class Op(val id: String, val symbol: String, val label: String) {
    ADD("add", "+", "Addition"),
    SUB("sub", "\u2212", "Subtraction"),
    MUL("mul", "\u00D7", "Multiplication"),
    DIV("div", "\u00F7", "Division"),
    MIX("mix", "\u00B1", "Mix"),
}

val REAL_OPS = listOf(Op.ADD, Op.SUB, Op.MUL, Op.DIV)

data class DigitTier(val id: Int, val digitLabel: String, val title: String, val rangeDesc: String)

val TIERS = listOf(
    DigitTier(1, "1", "Single digit", "numbers 1-9"),
    DigitTier(2, "2", "Double digit", "numbers 10-99"),
    DigitTier(3, "3", "Triple digit", "numbers 100-999"),
    DigitTier(4, "\u221E", "Mixed digits", "random size each time"),
)

val DURATIONS = listOf(30, 60, 120)

data class Problem(val text: String, val answer: Int)

fun rangeFor(tierId: Int): IntRange = when (tierId) {
    1 -> 1..9
    2 -> 10..99
    3 -> 100..999
    else -> 1..9
}

fun generateProblem(tier: DigitTier, op: Op): Problem {
    val actualTierId = if (tier.id == 4) listOf(1, 2, 3).random() else tier.id
    val range = rangeFor(actualTierId)
    val actualOp = if (op == Op.MIX) REAL_OPS.random() else op
    return when (actualOp) {
        Op.ADD -> {
            val a = range.random(); val b = range.random()
            Problem("$a + $b", a + b)
        }
        Op.SUB -> {
            var a = range.random(); var b = range.random()
            if (a < b) { val t = a; a = b; b = t }
            Problem("$a \u2212 $b", a - b)
        }
        Op.MUL -> {
            val a = range.random(); val b = (2..9).random()
            Problem("$a \u00D7 $b", a * b)
        }
        Op.DIV -> {
            val q = range.random(); val d = (2..9).random()
            val dividend = q * d
            Problem("$dividend \u00F7 $d", q)
        }
        else -> {
            val a = range.random(); val b = range.random()
            Problem("$a + $b", a + b)
        }
    }
}

fun comboKey(tier: DigitTier, op: Op): String = "${tier.id}_${op.id}"

// ---------- Persistence ----------

data class HistoryEntry(val ts: Long, val avgSec: Double, val accuracy: Int, val score: Int)

fun prefs(context: Context) = context.getSharedPreferences("quickmath", Context.MODE_PRIVATE)

fun loadBest(context: Context, key: String): Int? {
    val v = prefs(context).getInt("best_$key", -1)
    return if (v >= 0) v else null
}

fun saveBest(context: Context, key: String, score: Int) {
    prefs(context).edit().putInt("best_$key", score).apply()
}

fun loadHistory(context: Context, key: String): List<HistoryEntry> {
    val raw = prefs(context).getString("hist_$key", null) ?: return emptyList()
    return try {
        val arr = JSONArray(raw)
        (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            HistoryEntry(o.getLong("ts"), o.getDouble("avg"), o.getInt("acc"), o.getInt("score"))
        }
    } catch (e: Exception) {
        emptyList()
    }
}

fun appendHistory(context: Context, key: String, entry: HistoryEntry): List<HistoryEntry> {
    val updated = (loadHistory(context, key) + entry).let {
        if (it.size > 25) it.takeLast(25) else it
    }
    val arr = JSONArray()
    updated.forEach { e ->
        val o = JSONObject()
        o.put("ts", e.ts); o.put("avg", e.avgSec); o.put("acc", e.accuracy); o.put("score", e.score)
        arr.put(o)
    }
    prefs(context).edit().putString("hist_$key", arr.toString()).apply()
    return updated
}

fun resetAllData(context: Context) {
    prefs(context).edit().clear().apply()
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

enum class Screen { HOME, COUNTDOWN, GAME, RESULTS, PROGRESS, ADMIN }

// ---------- Root composable / state machine ----------

@Composable
fun AppRoot() {
    val context = LocalContext.current

    var screen by remember { mutableStateOf(Screen.HOME) }
    var selectedTier by remember { mutableStateOf(TIERS[0]) }
    var selectedOp by remember { mutableStateOf(Op.ADD) }
    var duration by remember { mutableIntStateOf(60) }

    var bestRefreshTick by remember { mutableIntStateOf(0) }
    val currentKey = comboKey(selectedTier, selectedOp)
    val currentBest = remember(currentKey, bestRefreshTick) { loadBest(context, currentKey) }
    val currentHistory = remember(currentKey, bestRefreshTick) { loadHistory(context, currentKey) }

    // Round state
    var score by remember { mutableIntStateOf(0) }
    var wrongAttempts by remember { mutableIntStateOf(0) }
    var streak by remember { mutableIntStateOf(0) }
    var bestStreak by remember { mutableIntStateOf(0) }
    var answerTimesSec by remember { mutableStateOf(listOf<Double>()) }
    var timeLeft by remember { mutableIntStateOf(60) }
    var currentProblem by remember { mutableStateOf(generateProblem(TIERS[0], Op.ADD)) }
    var questionStartMs by remember { mutableLongStateOf(0L) }
    var input by remember { mutableStateOf("") }
    var flashState by remember { mutableIntStateOf(0) } // 0 none, 1 correct, -1 wrong
    var lastFeedback by remember { mutableStateOf("") }
    var newBest by remember { mutableStateOf(false) }

    fun startRound() {
        score = 0; wrongAttempts = 0; streak = 0; bestStreak = 0
        answerTimesSec = emptyList()
        timeLeft = duration
        currentProblem = generateProblem(selectedTier, selectedOp)
        questionStartMs = System.currentTimeMillis()
        input = ""
        flashState = 0
        lastFeedback = ""
        screen = Screen.GAME
    }

    fun submitAnswer() {
        if (screen != Screen.GAME) return
        val given = input.trim().toIntOrNull() ?: return

        if (given == currentProblem.answer) {
            val elapsedSec = (System.currentTimeMillis() - questionStartMs) / 1000.0
            answerTimesSec = answerTimesSec + elapsedSec
            score += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            flashState = 1
            lastFeedback = if (streak >= 3) "$streak in a row" else ""
            // Only advance to a new problem once the answer is correct.
            currentProblem = generateProblem(selectedTier, selectedOp)
            questionStartMs = System.currentTimeMillis()
            input = ""
        } else {
            wrongAttempts += 1
            streak = 0
            flashState = -1
            lastFeedback = "try again"
            input = ""
            // Same problem stays on screen until answered correctly.
        }
    }

    fun finishRound() {
        val total = score + wrongAttempts
        val accuracy = if (total > 0) (score * 100 / total) else 0
        val avgSec = if (answerTimesSec.isNotEmpty()) answerTimesSec.average() else 0.0

        val prev = loadBest(context, currentKey)
        if (prev == null || score > prev) {
            newBest = true
            saveBest(context, currentKey, score)
        } else {
            newBest = false
        }
        if (score > 0) {
            appendHistory(context, currentKey, HistoryEntry(System.currentTimeMillis(), avgSec, accuracy, score))
        }
        bestRefreshTick += 1
        screen = Screen.RESULTS
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
                selectedTier = selectedTier,
                selectedOp = selectedOp,
                duration = duration,
                best = currentBest,
                historyCount = currentHistory.size,
                onSelectTier = { selectedTier = it },
                onSelectOp = { selectedOp = it },
                onSelectDuration = { duration = it },
                onStart = { screen = Screen.COUNTDOWN },
                onViewProgress = { screen = Screen.PROGRESS },
                onOpenAdmin = { screen = Screen.ADMIN },
            )
            Screen.COUNTDOWN -> CountdownScreen(
                levelName = "${selectedTier.title} \u00B7 ${selectedOp.label}",
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
                tier = selectedTier,
                op = selectedOp,
                duration = duration,
                score = score,
                wrongAttempts = wrongAttempts,
                bestStreak = bestStreak,
                answerTimesSec = answerTimesSec,
                isNewBest = newBest,
                onChangeLevel = { screen = Screen.HOME },
                onPlayAgain = { screen = Screen.COUNTDOWN },
                onViewProgress = { screen = Screen.PROGRESS },
            )
            Screen.PROGRESS -> ProgressScreen(
                tier = selectedTier,
                op = selectedOp,
                history = currentHistory,
                onBack = { screen = if (score + wrongAttempts > 0) Screen.RESULTS else Screen.HOME },
            )
            Screen.ADMIN -> AdminScreen(
                onBack = { screen = Screen.HOME },
                onReset = {
                    resetAllData(context)
                    bestRefreshTick += 1
                },
            )
        }
    }
}

// ---------- Home ----------

@Composable
fun HomeScreen(
    selectedTier: DigitTier,
    selectedOp: Op,
    duration: Int,
    best: Int?,
    historyCount: Int,
    onSelectTier: (DigitTier) -> Unit,
    onSelectOp: (Op) -> Unit,
    onSelectDuration: (Int) -> Unit,
    onStart: () -> Unit,
    onViewProgress: () -> Unit,
    onOpenAdmin: () -> Unit,
) {
    Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = "Quick Math Sprint", color = TextMain, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Box(
                modifier = Modifier
                    .border(1.dp, LineColor, RoundedCornerShape(8.dp))
                    .clickable { onOpenAdmin() }
                    .padding(horizontal = 10.dp, vertical = 6.dp)
            ) {
                Text(text = "\u2699", color = Muted, fontSize = 16.sp)
            }
        }
        Spacer(modifier = Modifier.height(18.dp))

        SectionLabel("digit level")
        Spacer(modifier = Modifier.height(8.dp))
        TIERS.forEach { tier ->
            TierRow(tier = tier, selected = tier.id == selectedTier.id, onClick = { onSelectTier(tier) })
            Spacer(modifier = Modifier.height(8.dp))
        }

        Spacer(modifier = Modifier.height(10.dp))
        SectionLabel("operation")
        Spacer(modifier = Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(Op.ADD, Op.SUB, Op.MUL).forEach { op ->
                OpChip(op, op == selectedOp, Modifier.weight(1f)) { onSelectOp(op) }
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(Op.DIV, Op.MIX).forEach { op ->
                OpChip(op, op == selectedOp, Modifier.weight(1f)) { onSelectOp(op) }
            }
            Spacer(modifier = Modifier.weight(1f))
        }

        Spacer(modifier = Modifier.height(20.dp))
        Divider(color = LineColor)
        Spacer(modifier = Modifier.height(16.dp))

        SectionLabel("round length")
        Spacer(modifier = Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            DURATIONS.forEach { d ->
                val active = d == duration
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .border(1.dp, if (active) Amber else LineColor, RoundedCornerShape(8.dp))
                        .background(Surface, RoundedCornerShape(8.dp))
                        .clickable { onSelectDuration(d) }
                        .padding(vertical = 10.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(text = "${d}s", color = if (active) Amber else Muted, fontFamily = FontFamily.Monospace, fontSize = 13.sp)
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, LineColor, RoundedCornerShape(10.dp))
                .padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text(
                    text = if (best != null) "best $best" else "no runs yet",
                    color = if (best != null) Green else Muted,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 14.sp,
                )
                Text(text = "${selectedTier.title} \u00B7 ${selectedOp.label}", color = Muted, fontSize = 11.sp)
            }
            if (historyCount > 0) {
                Text(
                    text = "progress \u2192",
                    color = Amber,
                    fontSize = 13.sp,
                    modifier = Modifier.clickable { onViewProgress() },
                )
            }
        }

        Spacer(modifier = Modifier.height(18.dp))

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(Amber, RoundedCornerShape(10.dp))
                .clickable { onStart() }
                .padding(vertical = 15.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = "Start round", color = Color(0xFF14181F), fontWeight = FontWeight.Bold, fontSize = 15.sp)
        }
        Spacer(modifier = Modifier.height(10.dp))
    }
}

@Composable
fun SectionLabel(text: String) {
    Text(text = text, color = Muted, fontSize = 12.sp)
}

@Composable
fun TierRow(tier: DigitTier, selected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, if (selected) Amber else LineColor, RoundedCornerShape(10.dp))
            .background(Surface, RoundedCornerShape(10.dp))
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = tier.digitLabel,
            color = if (selected) Amber else Muted,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
            modifier = Modifier.width(30.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(text = tier.title, color = TextMain, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            Text(text = tier.rangeDesc, color = Muted, fontSize = 12.sp)
        }
    }
}

@Composable
fun OpChip(op: Op, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier
            .border(1.dp, if (selected) Amber else LineColor, RoundedCornerShape(8.dp))
            .background(Surface, RoundedCornerShape(8.dp))
            .clickable { onClick() }
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "${op.symbol} ${op.label}",
            color = if (selected) Amber else Muted,
            fontSize = 12.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
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

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
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
                textStyle = TextStyle(
                    fontFamily = FontFamily.Monospace,
                    fontSize = 22.sp,
                    textAlign = TextAlign.Center,
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
            color = if (flashState == -1) Red else if (streak >= 3) Amber else Muted,
            fontSize = 12.sp,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
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

// ---------- Simple line chart (no external chart library needed) ----------

@Composable
fun LineChart(
    values: List<Float>,
    modifier: Modifier = Modifier,
    lineColor: Color = Amber,
) {
    Canvas(modifier = modifier) {
        if (values.isEmpty()) return@Canvas
        if (values.size == 1) {
            drawCircle(color = lineColor, radius = 5f, center = Offset(size.width / 2f, size.height / 2f))
            return@Canvas
        }
        val maxV = values.max()
        val minV = values.min()
        val range = (maxV - minV).let { if (it > 0f) it else 1f }
        val stepX = size.width / (values.size - 1)
        val points = values.mapIndexed { i, v ->
            val normalized = (v - minV) / range
            Offset(x = i * stepX, y = size.height - normalized * size.height * 0.85f - size.height * 0.075f)
        }
        for (i in 0 until points.size - 1) {
            drawLine(color = lineColor, start = points[i], end = points[i + 1], strokeWidth = 4f)
        }
        points.forEach { p -> drawCircle(color = lineColor, radius = 5f, center = p) }
    }
}

// ---------- Results ----------

@Composable
fun ResultsScreen(
    tier: DigitTier,
    op: Op,
    duration: Int,
    score: Int,
    wrongAttempts: Int,
    bestStreak: Int,
    answerTimesSec: List<Double>,
    isNewBest: Boolean,
    onChangeLevel: () -> Unit,
    onPlayAgain: () -> Unit,
    onViewProgress: () -> Unit,
) {
    val total = score + wrongAttempts
    val accuracy = if (total > 0) (score * 100 / total) else 0
    val avgTimeSec = if (answerTimesSec.isNotEmpty()) answerTimesSec.average() else 0.0

    Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
        Text(text = "${tier.title} \u00B7 ${op.label}", color = TextMain, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Text(
            text = "${duration}s round",
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
                StatCell("wrong attempts", wrongAttempts.toString(), Red, Modifier.weight(1f))
            }
            Divider(color = LineColor)
            Row(modifier = Modifier.fillMaxWidth()) {
                StatCell("accuracy", "$accuracy%", Amber, Modifier.weight(1f))
                StatCell("avg time / answer", String.format("%.1fs", avgTimeSec), TextMain, Modifier.weight(1f))
            }
            Divider(color = LineColor)
            Row(modifier = Modifier.fillMaxWidth()) {
                StatCell("best streak", bestStreak.toString(), TextMain, Modifier.weight(1f))
                StatCell("questions solved", score.toString(), TextMain, Modifier.weight(1f))
            }
        }

        if (answerTimesSec.size >= 2) {
            Spacer(modifier = Modifier.height(22.dp))
            SectionLabel("time per question this round (s) \u2014 lower is faster")
            Spacer(modifier = Modifier.height(8.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp)
                    .border(1.dp, LineColor, RoundedCornerShape(10.dp))
                    .background(Surface, RoundedCornerShape(10.dp))
                    .padding(12.dp)
            ) {
                LineChart(
                    values = answerTimesSec.map { it.toFloat() },
                    modifier = Modifier.fillMaxSize(),
                    lineColor = Amber,
                )
            }
        }

        Spacer(modifier = Modifier.height(18.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, LineColor, RoundedCornerShape(10.dp))
                .clickable { onViewProgress() }
                .padding(vertical = 12.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = "View progress over time \u2192", color = Amber, fontSize = 13.sp)
        }

        Spacer(modifier = Modifier.height(14.dp))

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
        Spacer(modifier = Modifier.height(10.dp))
    }
}

@Composable
fun StatCell(label: String, value: String, color: Color, modifier: Modifier = Modifier) {
    Column(modifier = modifier.background(Surface).padding(16.dp)) {
        Text(text = value, color = color, fontFamily = FontFamily.Monospace, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(4.dp))
        Text(text = label, color = Muted, fontSize = 12.sp)
    }
}

// ---------- Progress (across rounds) ----------

@Composable
fun ProgressScreen(tier: DigitTier, op: Op, history: List<HistoryEntry>, onBack: () -> Unit) {
    Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
        Text(
            text = "\u2190 back",
            color = Amber,
            fontSize = 13.sp,
            modifier = Modifier.clickable { onBack() }.padding(bottom = 16.dp),
        )
        Text(text = "${tier.title} \u00B7 ${op.label}", color = TextMain, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Text(text = "last ${history.size} rounds", color = Muted, fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp, bottom = 18.dp))

        if (history.size < 2) {
            Text(
                text = "Play a couple more rounds at this level and operation to see your speed trend here.",
                color = Muted,
                fontSize = 13.sp,
            )
            return@Column
        }

        SectionLabel("avg seconds per answer, by round \u2014 downward means you're getting faster")
        Spacer(modifier = Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp)
                .border(1.dp, LineColor, RoundedCornerShape(10.dp))
                .background(Surface, RoundedCornerShape(10.dp))
                .padding(12.dp)
        ) {
            LineChart(
                values = history.map { it.avgSec.toFloat() },
                modifier = Modifier.fillMaxSize(),
                lineColor = Amber,
            )
        }

        Spacer(modifier = Modifier.height(20.dp))
        SectionLabel("accuracy % per round")
        Spacer(modifier = Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .border(1.dp, LineColor, RoundedCornerShape(10.dp))
                .background(Surface, RoundedCornerShape(10.dp))
                .padding(12.dp)
        ) {
            LineChart(
                values = history.map { it.accuracy.toFloat() },
                modifier = Modifier.fillMaxSize(),
                lineColor = Green,
            )
        }

        Spacer(modifier = Modifier.height(20.dp))
        val first = history.first().avgSec
        val last = history.last().avgSec
        val diff = first - last
        val improved = diff > 0.05
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, if (improved) Green else LineColor, RoundedCornerShape(10.dp))
                .padding(14.dp)
        ) {
            Text(
                text = if (improved)
                    String.format("You've sped up by %.1fs per answer since your first round here.", diff)
                else
                    "Keep going \u2014 your speed trend will show here as you play more rounds.",
                color = if (improved) Green else Muted,
                fontSize = 13.sp,
            )
        }
        Spacer(modifier = Modifier.height(10.dp))
    }
}

// ---------- Admin ----------

@Composable
fun AdminScreen(onBack: () -> Unit, onReset: () -> Unit) {
    var confirming by remember { mutableStateOf(false) }
    var didReset by remember { mutableStateOf(false) }

    Column {
        Text(
            text = "\u2190 back",
            color = Amber,
            fontSize = 13.sp,
            modifier = Modifier.clickable { onBack() }.padding(bottom = 16.dp),
        )
        Text(text = "Admin", color = TextMain, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(18.dp))

        if (didReset) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, Green, RoundedCornerShape(8.dp))
                    .background(Green.copy(alpha = 0.12f), RoundedCornerShape(8.dp))
                    .padding(12.dp)
            ) {
                Text("All saved scores and history have been cleared.", color = Green, fontSize = 13.sp)
            }
            Spacer(modifier = Modifier.height(18.dp))
        }

        Text(
            text = "This clears every best score and every round's saved history, for every level and operation. This can't be undone.",
            color = Muted,
            fontSize = 13.sp,
        )
        Spacer(modifier = Modifier.height(18.dp))

        if (!confirming) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, Red, RoundedCornerShape(10.dp))
                    .clickable { confirming = true }
                    .padding(vertical = 13.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(text = "Reset all data", color = Red, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            }
        } else {
            Text(text = "Are you sure? This deletes everything saved.", color = TextMain, fontSize = 13.sp)
            Spacer(modifier = Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(
                    onClick = { confirming = false },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(10.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, LineColor),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = TextMain),
                ) {
                    Text("Cancel")
                }
                Button(
                    onClick = {
                        onReset()
                        confirming = false
                        didReset = true
                    },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Red, contentColor = Color.White),
                ) {
                    Text("Yes, reset", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
QMS_EOF

git add -A
git commit -m "Add operation choice per level, hold-until-correct, progress charts, admin reset"
git push

