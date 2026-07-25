import 'package:flutter/material.dart';

class NotificationItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String time;
  final bool isRead;
  final VoidCallback? onTap;
  final double screenHeight;
  final Color cardColor;
  final Color borderColor;
  final Color shadowColor;
  final Color unreadDotColor;
  final int animationOrder;

  const NotificationItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.time,
    required this.isRead,
    this.onTap,
    required this.screenHeight,
    required this.cardColor,
    required this.borderColor,
    required this.shadowColor,
    required this.unreadDotColor,
    this.animationOrder = 0,
  });

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: (animationOrder.clamp(0, 8)) * 45);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: Duration(milliseconds: 430 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: 1 - value,
          child: Transform.translate(
            offset: Offset(34 * value, 0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: screenHeight * 0.014),
          padding: EdgeInsets.all(screenHeight * 0.016),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(screenHeight * 0.011),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: screenHeight * 0.024,
                ),
              ),
              SizedBox(width: screenHeight * 0.016),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: screenHeight * 0.016,
                        fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                        color: const Color(0xFF2E2E2E),
                        height: 1.2,
                      ),
                    ),
                    if (body.trim().isNotEmpty) ...[
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: screenHeight * 0.0135,
                          color: const Color(0xFF6C6C6C),
                          height: 1.35,
                        ),
                      ),
                    ],
                    SizedBox(height: screenHeight * 0.008),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: screenHeight * 0.013,
                          color: const Color(0xFF8A8A8A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: screenHeight * 0.012,
                            color: const Color(0xFF8A8A8A),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  margin: const EdgeInsets.only(left: 10, top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: unreadDotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: unreadDotColor.withValues(alpha: 0.55),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
