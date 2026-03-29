import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _accent = Color(0xFF6C47FF);
  static const _accentLight = Color(0xFFEDE9FF);
  static const _ink = Color(0xFF1A1A1A);
  static const _inkMuted = Color(0xFF6B6B6B);
  static const _bg = Color(0xFFF7F5F2);

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'sunil.cs24024@mmcc.edu.in',
      query: 'subject=NextUp App Support&body=Hello, I need help with...',
    );
    if (!await launchUrl(emailUri)) {
      throw Exception('Could not launch email client');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 190,
            collapsedHeight: 56,
            pinned: true,
            backgroundColor: _accent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.maybePop(context),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
              title: const Text(
                '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              background: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF7C5CFF), Color(0xFF3D1BCC)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -20,
                    right: -20,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.07),
                      ),
                      child: const SizedBox(width: 150, height: 150),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: -30,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                      child: const SizedBox(width: 100, height: 100),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Text(
                              'NextUp Support',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'How can we\nhelp you?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                _SectionLabel(label: 'ABOUT NEXTUP'),
                const SizedBox(height: 8),
                _SimpleCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: _accentLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(9),
                          child: Icon(Icons.queue_rounded, color: _accent, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'NextUp is a Virtual Queue Management System designed to '
                              'eliminate physical lines. Join queues remotely, track your '
                              'position, and get notified when your turn approaches.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: _inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _SectionLabel(label: 'HOW TO USE'),
                const SizedBox(height: 8),
                _StepsCard(
                  icon: Icons.person_rounded,
                  role: 'For Users (Customers)',
                  steps: const [
                    'Register or log in to your account.',
                    'Scan a QR code to Join a Virtual Queue',
                    'Receive a virtual token and track your position.',
                    'Get notified as your turn approaches.',
                  ],
                ),
                const SizedBox(height: 10),
                _StepsCard(
                  icon: Icons.storefront_rounded,
                  role: 'For Service Providers',
                  steps: const [
                    'Register as a Service Provider from the signup screen.',
                    'Add service details like name, discription and limits.',
                    'Manage customer tokens efficiently.',
                    'View analytics and monitor queue performance.',
                  ],
                ),
                const SizedBox(height: 24),

                _SectionLabel(label: 'FREQUENTLY ASKED'),
                const SizedBox(height: 8),
                _FAQTile(
                  question: "Why can't I join a queue?",
                  answer:
                  'Ensure you have a stable internet connection and the service is open for queue registration.',
                ),
                _FAQTile(
                  question: 'Can I cancel a token?',
                  answer:
                  'Yes — navigate to "My Tokens", select the token, then tap "Cancel Token."',
                ),
                _FAQTile(
                  question: 'What if I miss my turn?',
                  answer:
                  "You can rejoin the queue, but you'll be placed at the end of the waiting list.",
                ),
                const SizedBox(height: 24),

                _SectionLabel(label: 'CONTACT US'),
                const SizedBox(height: 8),
                _ContactCard(onEmailTap: _launchEmail),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFC8A96E),
            borderRadius: BorderRadius.circular(2),
          ),
          child: const SizedBox(width: 3, height: 13),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: HelpPage._inkMuted,
          ),
        ),
      ],
    );
  }
}

// ── Simple Card ───────────────────────────────────────────────────────────
class _SimpleCard extends StatelessWidget {
  final Widget child;
  const _SimpleCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

// ── Steps Card ────────────────────────────────────────────────────────────
class _StepsCard extends StatelessWidget {
  final IconData icon;
  final String role;
  final List<String> steps;

  const _StepsCard({
    required this.icon,
    required this.role,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: HelpPage._accentLight,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(icon, color: HelpPage._accent, size: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HelpPage._ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...steps.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: HelpPage._accentLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: Center(
                          child: Text(
                            '${e.key + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: HelpPage._accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: HelpPage._inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── FAQ Tile ──────────────────────────────────────────────────────────────
class _FAQTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQTile({required this.question, required this.answer});

  @override
  State<_FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<_FAQTile> with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: _open
                ? HelpPage._accent.withOpacity(0.4)
                : const Color(0xFFEAE8E4),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            children: [
              InkWell(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: _open ? HelpPage._accent : HelpPage._accentLight,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            Icons.help_outline_rounded,
                            color: _open ? Colors.white : HelpPage._accent,
                            size: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.question,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _open ? HelpPage._accent : HelpPage._ink,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 240),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _open ? HelpPage._accent : HelpPage._inkMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizeTransition(
                sizeFactor: _anim,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(42, 0, 14, 14),
                  child: Text(
                    widget.answer,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: HelpPage._inkMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Contact Card ─────────────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  final VoidCallback onEmailTap;
  const _ContactCard({required this.onEmailTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C5CFF), Color(0xFF3D1BCC)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C47FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: Icon(Icons.support_agent_rounded, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Still need help?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Our support team is ready to assist you with any questions.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onEmailTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email_rounded, color: HelpPage._accent, size: 17),
                      SizedBox(width: 7),
                      Text(
                        'Contact Support',
                        style: TextStyle(
                          color: HelpPage._accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
