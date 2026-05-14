class AppConstants {
  static const String appName = 'Picture Book App';
  static const String hiveBoxName = 'books';
  static const String aiSettingsBoxName = 'ai_settings';
  
  static const String booksDirectoryName = 'books';
  
  static const int maxPageSize = 100;
  static const int thumbnailSize = 200;
  
  static const String defaultBookTitle = '新点读本';
  
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
  
  static const List<double> systemTtsSpeedPresets = [0.1, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
  static const List<double> glmTtsSpeedPresets = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5];
}