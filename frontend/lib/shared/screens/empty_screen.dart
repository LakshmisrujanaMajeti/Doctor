import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/empty_state_widget.dart';

class EmptyScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showAppBar;
  final String appBarTitle;

  const EmptyScreen({
    super.key,
    this.title = 'No Records Found',
    this.description = 'There are currently no items available in this section.',
    this.icon = Icons.folder_open_rounded,
    this.actionLabel = 'Go to Dashboard',
    this.onAction,
    this.showAppBar = true,
    this.appBarTitle = 'OPD Records',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(appBarTitle),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/dashboard');
                  }
                },
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: EmptyStateWidget(
              icon: icon,
              title: title,
              message: description,
              actionLabel: actionLabel,
              onAction: onAction ?? () => context.go('/dashboard'),
            ),
          ),
        ),
      ),
    );
  }
}
