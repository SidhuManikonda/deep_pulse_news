import 'package:deep_pulse_news/core/routing/app_router.dart';
import 'package:deep_pulse_news/core/services/onboarding_storage.dart';
import 'package:deep_pulse_news/data/models/topic.dart';
import 'package:deep_pulse_news/enums/onboarding_enum.dart';
import 'package:deep_pulse_news/features/onboarding/topic_viewmodel.dart';
import 'package:deep_pulse_news/navigators/onboarding_navigator.dart';
import 'package:deep_pulse_news/providers/app_providers.dart';
import 'package:flutter/material.dart';
import '../../core/utils/onboarding_manager.dart';
import '../../core/utils/topic_styling_helper.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/category_chip.dart';
import '../../shared/widgets/shimmer_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TopicsSelectionScreen extends ConsumerStatefulWidget {
  const TopicsSelectionScreen({super.key});

  @override
  ConsumerState<TopicsSelectionScreen> createState() =>
      _TopicsSelectionScreenState();
}

class _TopicsSelectionScreenState extends ConsumerState<TopicsSelectionScreen> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(topicViewModelProvider).loadTopics();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final topicViewModel = ref.watch(topicViewModelProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Choose Topics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select topics you\'re interested in to get personalized news',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: topicViewModel.isLoading
                    ? _buildShimmerGrid()
                    : ListView.builder(
                        itemCount: (topicViewModel.topics.length / 2)
                            .ceil(), // Calculate rows needed
                        itemBuilder: (context, rowIndex) {
                          // Calculate start and end indices for this row
                          final startIndex = rowIndex * 2;
                          final topics = topicViewModel.topics;

                          // Check if first topic in this row has long text (should take full width)
                          final firstTopic = topics[startIndex];
                          final isLongText =
                              firstTopic.name.length >
                              20; // Threshold for "big" text

                          if (isLongText) {
                            // Single item row for long text
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildTopicChip(
                                      firstTopic,
                                      topicViewModel,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // Two items row for normal text
                            final secondTopic = startIndex + 1 < topics.length
                                ? topics[startIndex + 1]
                                : null;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildTopicChip(
                                      firstTopic,
                                      topicViewModel,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: secondTopic != null
                                        ? _buildTopicChip(
                                            secondTopic,
                                            topicViewModel,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                '${topicViewModel.selectedTopics.length} topics selected',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Continue',
                onPressed: topicViewModel.selectedTopics.isNotEmpty
                    ? () => _handleContinue(topicViewModel)
                    : null,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    // Simple shimmer with consistent 2-column layout
    const shimmerItemCount = 15;

    return ListView.builder(
      itemCount: (shimmerItemCount / 2).ceil(),
      itemBuilder: (context, rowIndex) {
        final startIndex = rowIndex * 2;
        final hasSecondItem = startIndex + 1 < shimmerItemCount;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(child: TopicChipShimmer(isFullWidth: false)),
              const SizedBox(width: 12),
              Expanded(
                child: hasSecondItem
                    ? TopicChipShimmer(isFullWidth: false)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleTopic(Topic topic, TopicViewmodel topicViewmodel) {
    setState(() {
      if (topicViewmodel.selectedTopics.contains(topic.id.toString())) {
        topicViewmodel.selectedTopics.remove(topic.id.toString());
      } else {
        topicViewmodel.selectedTopics.add(topic.id.toString());
      }
    });
  }

  Widget _buildTopicChip(Topic topic, TopicViewmodel topicViewmodel) {
    final isSelected = topicViewmodel.selectedTopics.contains(
      topic.id.toString(),
    );

    // Get emoji and color for this topic
    final styling = TopicStylingHelper.getTopicStyling(topic);

    return CategoryChip(
      label: topic.name,
      emoji: styling.emoji,
      isSelected: isSelected,
      backgroundColor: styling.color,
      onTap: () => _toggleTopic(topic, topicViewmodel),
    );
  }

  void _handleContinue(TopicViewmodel topicViewmodel) async {
    if (topicViewmodel.selectedTopics.isEmpty) return;

    try {
      final storage = OnboardingStorage();
      
      // Save selected topics to storage
      final selectedTopicsList = <Map<String, dynamic>>[];
      for (final topicId in topicViewmodel.selectedTopics) {
        // Find the topic object to get ID and name
        final topic = topicViewmodel.topics.firstWhere(
          (t) => t.id.toString() == topicId,
        );
        selectedTopicsList.add({
          'id': topic.id,
          'name': topic.name,
        });
      }
      await storage.saveSelectedTopics(selectedTopicsList);
      
      await storage.setTopicsCompleted();
      await storage.setOnboardingCompleted();

      final onboardingManager = OnboardingManager(storage);
      final step = await onboardingManager.getCurrentStep();
      OnboardingNavigator.navigate(context, step, replace: false);
    } catch (e) {
      debugPrint('Topics onboarding error: $e');
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (_) => false);
    }
  }
}
