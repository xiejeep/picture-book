class AppPrompts {
  static String visionExtractText() {
    return '''This is a page from a children's English picture book.

TASK: Extract ALL English text visible in this image.

RULES:
1. List every English word, phrase, or sentence you can see
2. Keep the text exactly as shown — do NOT translate, correct, or paraphrase
3. Include phonetic guides if visible (e.g. /haus/)
4. Include decorative or heading text if present
5. If there is Chinese text, ignore it
6. Describe the approximate position of each text (e.g. "top-left", "center", "bottom-right")
7. Preserve line breaks within a text block

OUTPUT: Plain text, one text item per line, with position info.
Example:
[top-left] house /haus/
[center] I build a house.
[bottom-right] Punch a tree\\nBuild a shelter

Do NOT output JSON. Just plain text with position annotations.''';
  }

  static String textCleanBatch({
    required String escapedVisionContext,
    required int count,
    required int firstIndex,
    required int lastIndex,
    required String blocksInput,
  }) {
    return '''TASK: Clean OCR text from a children's English picture book.

=== IMAGE REFERENCE (text extracted from the book page by vision AI) ===
$escapedVisionContext

=== OCR BLOCKS TO CLEAN ($count blocks, indices $firstIndex to $lastIndex) ===
$blocksInput

=== RULES ===

1. ONE-TO-ONE MAPPING (CRITICAL):
   - Input has $count blocks → Output MUST have exactly $count blocks
   - Each input index MUST appear in output with THE SAME index number
   - MISSING ANY INDEX = COMPLETE FAILURE

2. USE THE IMAGE REFERENCE to help identify real text vs OCR noise:
   - If OCR says "hou5e" but image reference says "house", correct to "house"
   - If OCR says "Punch a tree ES" and image shows "Punch a tree", remove noise "ES"
   - If OCR text is NOT found in the image reference at all, it may be noise

3. EACH BLOCK IS AN INDEPENDENT OCR REGION (CRITICAL):
   - Every block comes from a SEPARATE rectangular area on the page
   - DO NOT merge adjacent blocks, even if they form a logical unit
   - DO NOT split multi-line blocks (containing \\n) into separate indices

4. CLEANING RULES:
   - Remove phonetic transcriptions: /haus/, /mi:t/, /ˈpɪkæks/ (entire /.../ pattern)
   - Remove decorative symbols: #, ##, |, **, numbering prefixes
   - Remove OCR noise: "F#At", "FRA", "FAABMA!", "60t9!", "ES", "AO" etc.
   - Remove Chinese characters — keep ONLY English text
   - Join multi-line text (\\n) into one line with spaces
   - Empty/garbage → corrected=""

=== OUTPUT FORMAT ===
Return ONLY a JSON object (no markdown, no explanation):
{"blocks":[{"index":$firstIndex,"corrected":"..."},{"index":${firstIndex + 1},"corrected":"..."},...,{"index":$lastIndex,"corrected":"..."}]}

You MUST output exactly $count blocks with indices $firstIndex through $lastIndex.''';
  }

  static String translationRefineBatch({
    required String escapedVisionContext,
    required int count,
    required int firstIndex,
    required int lastIndex,
    required String blocksInput,
  }) {
    return '''你是一个专业翻译校对助手。

=== 图片内容描述 ===
$escapedVisionContext

=== 待翻译文本块 ($count blocks, indices $firstIndex to $lastIndex) ===
每个块包含英文原文和机器翻译草稿。
$blocksInput

=== 任务 ===
根据图片内容理解文本的语境，对机器翻译草稿进行二次优化：

1. 结合图片理解文本的上下文和场景，翻译要符合图片中的语境
2. 纠正机器翻译中生硬、不准确或不自然的地方
3. 保持翻译简洁自然，通俗易懂
4. 如果草稿翻译已经很好，可以保留
5. 每个块独立翻译，不要合并或拆分

=== 输出格式 ===
返回JSON（不要markdown，不要解释）：
{"blocks":[{"index":$firstIndex,"translation":"优化后的中文翻译"},{"index":${firstIndex + 1},"translation":"..."},...,{"index":$lastIndex,"translation":"..."}]}

严格输出$count个块，索引从$firstIndex到$lastIndex。''';
  }

  static const String aiUsageNotice = '使用AI功能时，您的文本和图片将发送给第三方AI服务商（智谱AI）进行处理。';
  static const String aiAccuracyNotice = '提示：AI识别结果可能不完全准确，建议手动检查和修改。';
}
