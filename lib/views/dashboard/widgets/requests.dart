import 'package:funclash/common/common.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/icons/icons.dart';
import 'package:funclash/providers/app.dart';
import 'package:funclash/views/connection/requests.dart';
import 'package:funclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'feed_card.dart';

class RequestsCard extends StatelessWidget {
  const RequestsCard({super.key});

  void _openRequests(BuildContext context) {
    showSnapSheet(
      context,
      initialScrollOffset: double.maxFinite,
      builder: (_, controller) => NestedPagedSheet(
        builder: (_) => RequestsView(scrollController: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FeedCard(
      label: PageLabel.requests.label,
      glyph: AppGlyphs.requests,
      onPressed: () => _openRequests(context),
      child: ThrottledFeedCount(provider: requestCountProvider),
    );
  }
}
