import 'package:funclash/common/common.dart';
import 'package:funclash/icons/icons.dart';
import 'package:funclash/views/config/filters.dart';
import 'package:funclash/views/config/icon_sets.dart';
import 'package:funclash/views/config/providers.dart';
import 'package:funclash/views/profiles/custom/custom_proxies.dart';
import 'package:funclash/widgets/list.dart';
import 'package:funclash/widgets/scaffold.dart';
import 'package:material_ui/material_ui.dart';

class CustomResourcesView extends StatelessWidget {
  const CustomResourcesView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final items = [
      ListItem.open(
        title: Text(appLocalizations.proxies),
        leading: const GlyphIcon(AppGlyphs.proxies),
        widget: const CustomProxiesView(),
      ),
      ListItem.open(
        title: Text(appLocalizations.ruleProviders),
        leading: const GlyphIcon(AppGlyphs.resources),
        widget: const ClashProvidersView(),
      ),
      ListItem.open(
        title: Text(appLocalizations.filters),
        leading: const GlyphIcon(AppGlyphs.filter),
        widget: const FiltersView(),
      ),
      ListItem.open(
        title: Text(appLocalizations.iconSets),
        leading: const GlyphIcon(AppGlyphs.photos),
        widget: const IconSetsView(),
      ),
    ];
    return BaseScaffold(
      title: appLocalizations.customProfileResources,
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(top: context.contentTopPadding, bottom: 16),
        children: [generateSectionV3(items: items)],
      ),
    );
  }
}
