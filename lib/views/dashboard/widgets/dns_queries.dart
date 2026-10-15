import 'package:funclash/common/common.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/icons/icons.dart';
import 'package:funclash/providers/app.dart';
import 'package:funclash/views/dns_queries.dart';
import 'package:funclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'feed_card.dart';

class DnsQueriesCard extends StatelessWidget {
  const DnsQueriesCard({super.key});

  void _openDnsQueries(BuildContext context) {
    showSnapSheet(
      context,
      initialScrollOffset: double.maxFinite,
      builder: (_, controller) => NestedPagedSheet(
        builder: (_) => DnsQueriesView(scrollController: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FeedCard(
      label: PageLabel.dns.label,
      glyph: AppGlyphs.dns,
      onPressed: () => _openDnsQueries(context),
      child: ThrottledFeedCount(provider: dnsQueryCountProvider),
    );
  }
}
