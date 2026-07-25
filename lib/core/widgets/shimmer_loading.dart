import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading {
  /// Basic placeholder container used across all shimmers
  static Widget _shimmerContainer({
    required double width,
    required double height,
    double borderRadius = 12,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// List of horizontal cards (used for Nearest, Offers, etc)
  static Widget buildHorizontalCardList({
    required double cardWidth,
    required double cardHeight,
    int itemCount = 4,
  }) {
    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, i) {
          return Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _shimmerContainer(width: double.infinity, height: double.infinity),
                ),
                const SizedBox(height: 8),
                _shimmerContainer(width: cardWidth * 0.4, height: 12),
                const SizedBox(height: 6),
                _shimmerContainer(width: cardWidth * 0.8, height: 14),
              ],
            ),
          );
        },
      ),
    );
  }

  /// List of horizontal chips (used for categories)
  static Widget buildHorizontalChips({int itemCount = 5}) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, i) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: _shimmerContainer(width: 80, height: 40, borderRadius: 20),
          );
        },
      ),
    );
  }

  /// List of vertical post cards (used for Recent Posts)
  static Widget buildPostList({int itemCount = 3}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _shimmerContainer(width: 40, height: 40, borderRadius: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerContainer(width: 120, height: 14),
                      const SizedBox(height: 6),
                      _shimmerContainer(width: 80, height: 10),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _shimmerContainer(width: double.infinity, height: 14),
              const SizedBox(height: 6),
              _shimmerContainer(width: 250, height: 14),
              const SizedBox(height: 12),
              _shimmerContainer(width: double.infinity, height: 180, borderRadius: 12),
            ],
          ),
        );
      },
    );
  }

  /// List of vertical list items (used for Reviews, History, Tickets)
  static Widget buildVerticalList({int itemCount = 5}) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerContainer(width: 60, height: 60, borderRadius: 12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 4),
                    _shimmerContainer(width: double.infinity, height: 16),
                    const SizedBox(height: 8),
                    _shimmerContainer(width: 120, height: 14),
                    const SizedBox(height: 12),
                    _shimmerContainer(width: 80, height: 14),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Full screen details shimmer (used for Place Details, Offer Details)
  static Widget buildDetailsScreen() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerContainer(width: double.infinity, height: 300, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerContainer(width: 200, height: 28),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _shimmerContainer(width: 100, height: 16),
                    const Spacer(),
                    _shimmerContainer(width: 60, height: 16),
                  ],
                ),
                const SizedBox(height: 24),
                _shimmerContainer(width: 140, height: 20),
                const SizedBox(height: 12),
                _shimmerContainer(width: double.infinity, height: 14),
                const SizedBox(height: 8),
                _shimmerContainer(width: double.infinity, height: 14),
                const SizedBox(height: 8),
                _shimmerContainer(width: 250, height: 14),
                const SizedBox(height: 32),
                _shimmerContainer(width: double.infinity, height: 160, borderRadius: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
