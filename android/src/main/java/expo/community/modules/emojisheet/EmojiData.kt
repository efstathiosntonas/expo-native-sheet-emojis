package expo.community.modules.emojisheet

import android.content.Context
import android.os.Build
import org.json.JSONArray

data class EmojiItem(
    val emoji: String,
    val name: String,
    val v: String,
    val toneEnabled: Boolean,
    val keywords: List<String>,
    val id: String
)

data class EmojiCategory(
    val title: String,
    val data: List<EmojiItem>
)

object EmojiData {

    val categoryDisplayNames = mapOf(
        "frequently_used" to "Frequently Used",
        "smileys_emotion" to "Smileys & Emotion",
        "people_body" to "People & Body",
        "animals_nature" to "Animals & Nature",
        "food_drink" to "Food & Drink",
        "travel_places" to "Travel & Places",
        "activities" to "Activities",
        "objects" to "Objects",
        "symbols" to "Symbols",
        "flags" to "Flags"
    )


    fun loadCategories(context: Context): List<EmojiCategory> {
        val json = context.assets.open("emojis.json").bufferedReader().use { it.readText() }
        val array = JSONArray(json)
        val categories = mutableListOf<EmojiCategory>()
        val maxVersion = maxSupportedEmojiVersion()
        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            val title = obj.getString("title")
            val dataArray = obj.getJSONArray("data")
            val items = mutableListOf<EmojiItem>()
            for (j in 0 until dataArray.length()) {
                val item = dataArray.getJSONObject(j)
                val emojiVersion = item.getString("v").toDoubleOrNull() ?: 0.0
                if (emojiVersion > maxVersion) continue
                val keywordsArray = item.getJSONArray("keywords")
                val keywords = mutableListOf<String>()
                for (k in 0 until keywordsArray.length()) {
                    keywords.add(keywordsArray.getString(k))
                }
                items.add(
                    EmojiItem(
                        emoji = item.getString("emoji"),
                        name = item.getString("name"),
                        v = item.getString("v"),
                        toneEnabled = item.getBoolean("toneEnabled"),
                        keywords = keywords,
                        id = item.getString("id")
                    )
                )
            }
            categories.add(EmojiCategory(title = title, data = items))
        }
        return categories
    }

    // API level → max Unicode emoji version (conservative estimates)
    private fun maxSupportedEmojiVersion(): Double {
        return when {
            Build.VERSION.SDK_INT >= 35 -> 16.0
            Build.VERSION.SDK_INT >= 34 -> 15.0
            Build.VERSION.SDK_INT >= 33 -> 15.0
            Build.VERSION.SDK_INT >= 32 -> 14.0
            Build.VERSION.SDK_INT >= 31 -> 14.0
            Build.VERSION.SDK_INT >= 30 -> 13.1
            Build.VERSION.SDK_INT >= 29 -> 12.1
            Build.VERSION.SDK_INT >= 28 -> 11.0
            else -> 11.0
        }
    }

    fun displayName(categoryTitle: String, customNames: Map<String, String>? = null): String {
        customNames?.get(categoryTitle)?.let { return it }
        return categoryDisplayNames[categoryTitle] ?: categoryTitle.replace("_", " ")
            .replaceFirstChar { it.uppercase() }
    }

    fun applyTone(emoji: String, toneCodePoint: Int): String {
        val firstCodePoint = emoji.codePointAt(0)
        val charCount = Character.charCount(firstCodePoint)
        val rest = emoji.substring(charCount)
        return String(Character.toChars(firstCodePoint)) + String(Character.toChars(toneCodePoint)) + rest
    }

    val skinToneModifiers = listOf(
        0x1F3FB, // Light
        0x1F3FC, // Medium-light
        0x1F3FD, // Medium
        0x1F3FE, // Medium-dark
        0x1F3FF  // Dark
    )
}
