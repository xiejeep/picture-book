class AppConstants {
  static const String appName = '点读鸭';
  static const String hiveBoxName = 'books';
  static const String aiSettingsBoxName = 'ai_settings';

  static const String booksDirectoryName = 'books';

  static const int maxPageSize = 100;
  static const int thumbnailSize = 200;

  static const String defaultBookTitle = '新读本';

  static const String zhipuApiEndpoint =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  static const String zhipuTtsEndpoint =
      'https://open.bigmodel.cn/api/paas/v4/audio/speech';

  static const List<Map<String, String>> availableModels = [
    {'name': 'glm-4v-flash', 'label': 'GLM-4V-Flash (免费)', 'free': 'true'},
    // {'name': 'glm-4.6v-flash', 'label': 'GLM-4.6V-Flash (免费)', 'free': 'true'},
    {'name': 'glm-4.6v-flashx', 'label': 'GLM-4.6V-FlashX', 'free': 'false'},
    {'name': 'glm-5v-turbo', 'label': 'GLM-5V-Turbo', 'free': 'false'},
    {'name': 'glm-4v', 'label': 'GLM-4V', 'free': 'false'},
  ];

  static const String defaultModel = 'glm-4v-flash';

  static const String defaultTextModel = 'glm-4.7-flash';

  static const List<Map<String, String>> availableTextModels = [
    {'name': 'glm-4.7-flash', 'label': 'GLM-4.7-Flash (免费)', 'free': 'true'},
    {'name': 'glm-4.7-flashx', 'label': 'GLM-4.7-FlashX', 'free': 'false'},
    {'name': 'glm-5.1', 'label': 'GLM-5.1', 'free': 'false'},
  ];

  static const String secureStorageApiKeyKey = 'zhipu_api_key';

  static const List<Map<String, String>> ttsVoices = [
    {'name': 'tongtong', 'label': '彤彤 (默认)'},
    {'name': 'chuichui', 'label': '锤锤'},
    {'name': 'xiaochen', 'label': '小陈'},
    {'name': 'jam', 'label': 'Jam'},
    {'name': 'kazi', 'label': 'Kazi'},
    {'name': 'douji', 'label': 'Douji'},
    {'name': 'luodo', 'label': 'Luodo'},
  ];

  static const String defaultTtsVoice = 'tongtong';

  static const double systemTtsMinSpeed = 0.1;
  static const double systemTtsMaxSpeed = 1.0;
  static const double systemTtsDefaultSpeed = 0.5;
  static const int systemTtsSpeedDivisions = 7;

  static const double glmTtsMinSpeed = 0.5;
  static const double glmTtsMaxSpeed = 1.5;
  static const double glmTtsDefaultSpeed = 1.0;
  static const int glmTtsSpeedDivisions = 10;

  static const List<double> systemTtsSpeedPresets = [
    0.1,
    0.3,
    0.4,
    0.5,
    0.6,
    0.7,
    0.8,
    0.9,
    1.0
  ];
  static const List<double> glmTtsSpeedPresets = [
    0.5,
    0.6,
    0.7,
    0.8,
    0.9,
    1.0,
    1.1,
    1.2,
    1.3,
    1.4,
    1.5
  ];

  static const List<Map<String, String>> supertonicVoices = [
    {'name': 'M1', 'label': 'M1 (男声)'},
    {'name': 'M2', 'label': 'M2 (男声)'},
    {'name': 'M3', 'label': 'M3 (男声)'},
    {'name': 'M4', 'label': 'M4 (男声)'},
    {'name': 'M5', 'label': 'M5 (男声)'},
    {'name': 'F1', 'label': 'F1 (女声)'},
    {'name': 'F2', 'label': 'F2 (女声)'},
    {'name': 'F3', 'label': 'F3 (女声)'},
    {'name': 'F4', 'label': 'F4 (女声)'},
    {'name': 'F5', 'label': 'F5 (女声)'},
  ];

  static const String supertonicDefaultVoice = 'M1';
  static const String supertonicDefaultLang = 'en';

  static const int supertonicMinSteps = 1;
  static const int supertonicMaxSteps = 20;
  static const int supertonicDefaultSteps = 8;

  static const double supertonicMinSpeed = 0.5;
  static const double supertonicMaxSpeed = 2.0;
  static const double supertonicDefaultSpeed = 1.05;
  static const int supertonicSpeedDivisions = 30;

  static const String supertonicModelsDirName = 'supertonic_models';
  static const String supertonicOnnxDirName = 'onnx';

  static const List<String> supertonicBundledFiles = [
    'duration_predictor.onnx',
    'tts.json',
    'unicode_indexer.json',
  ];

  static const List<String> supertonicDownloadableFiles = [
    'text_encoder.onnx',
    'vector_estimator.onnx',
    'vocoder.onnx',
  ];

  static const List<String> supertonicRequiredModelFiles = [
    ...supertonicBundledFiles,
    ...supertonicDownloadableFiles,
  ];

  static const Map<String, String> supertonicModelUrlsHuggingface = {
    'text_encoder.onnx':
        'https://huggingface.co/Supertone/supertonic-3/resolve/main/onnx/text_encoder.onnx',
    'vector_estimator.onnx':
        'https://huggingface.co/Supertone/supertonic-3/resolve/main/onnx/vector_estimator.onnx',
    'vocoder.onnx':
        'https://huggingface.co/Supertone/supertonic-3/resolve/main/onnx/vocoder.onnx',
  };

  static const Map<String, String> supertonicModelUrlsModelscope = {
    'text_encoder.onnx':
        'https://modelscope.cn/models/Supertone/supertonic-3/resolve/master/onnx/text_encoder.onnx',
    'vector_estimator.onnx':
        'https://modelscope.cn/models/Supertone/supertonic-3/resolve/master/onnx/vector_estimator.onnx',
    'vocoder.onnx':
        'https://modelscope.cn/models/Supertone/supertonic-3/resolve/master/onnx/vocoder.onnx',
  };

  static const List<Map<String, String>> supertonicDownloadSources = [
    {'name': 'huggingface', 'label': 'HuggingFace (国际源)', 'region': '国际'},
    {'name': 'modelscope', 'label': 'ModelScope (国内源)', 'region': '国内'},
  ];

  static const String supertonicDefaultDownloadSource = 'modelscope';
}
