import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用教程'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppTheme.sweetPink,
                AppTheme.lavender,
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.warmGradientBox,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickStartSection(),
                const SizedBox(height: 24),
                _buildDetailedStepsSection(),
                const SizedBox(height: 24),
                _buildTipsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildQuickStartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '快速开始',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildStepCard(
          icon: Icons.photo_library,
          iconColor: Colors.blue,
          title: '1. 创建绘本',
          description: '在书架页面点击右上角"+"按钮，创建一个新的绘本',
          details: '支持从相册导入图片或拍照添加绘本内页',
        ),
        _buildStepCard(
          icon: Icons.text_fields,
          iconColor: Colors.green,
          title: '2. 识别文字',
          description: '在绘本详情页点击"识别文字"按钮',
          details: '使用ML Kit自动识别图片中的英文文字',
        ),
        _buildStepCard(
          icon: Icons.touch_app,
          iconColor: Colors.orange,
          title: '3. 点读文字',
          description: '点击识别出的文字方块即可播放语音',
          details: '支持系统语音或GLM-TTS高质量语音',
        ),
      ],
    );
  }

  Widget _buildDetailedStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '详细功能说明',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDetailItem(
          title: '配置AI功能',
          description: '在设置中配置智谱AI的API Key，即可启用AI强化识别和GLM-TTS语音功能',
          icon: Icons.auto_fix_high,
          color: Colors.purple,
        ),
        _buildDetailItem(
          title: 'AI强化识别',
          description: '自动去除音标符号、序号标记、装饰符号，保留纯净的英文文本',
          icon: Icons.auto_fix_high,
          color: Colors.blue,
        ),
        _buildDetailItem(
          title: '语速调节',
          description: '滑动选择合适的语速，GLM-TTS支持50%-150%速度调节',
          icon: Icons.speed,
          color: Colors.green,
        ),
        _buildDetailItem(
          title: 'TTS缓存',
          description: '相同文本+音色+语速组合会自动缓存，节省API调用',
          icon: Icons.storage,
          color: Colors.teal,
        ),
        _buildDetailItem(
          title: '绘本管理',
          description: '长按绘本可以编辑、删除或排序，密码保护防止误操作',
          icon: Icons.folder,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildTipsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              const Text(
                '使用技巧',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem('将绘本横屏拍摄效果更佳'),
          _buildTipItem('确保光线充足，避免阴影和反光'),
          _buildTipItem('文字清晰对焦，识别率更高'),
          _buildTipItem('推荐使用GLM-TTS获得更自然的语音'),
          _buildTipItem('可以调节语速适应儿童学习节奏'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.email, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '有使用问题或建议请联系邮箱：278245181@qq.com',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String details,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}