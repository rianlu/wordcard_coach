import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class CollectionGalleryScreen extends StatelessWidget {
  const CollectionGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
             _buildSectionHeader('Legendary Items', '1/12', Colors.yellow.shade700, const Color(0xFFFEF3C7)),
             const SizedBox(height: 16),
             _buildLegendaryCard(),
             const SizedBox(height: 32),
             
             _buildSectionHeader('Epic Adventures', '1/18', Colors.purple, Colors.purple.shade50, icon: Icons.auto_awesome),
             const SizedBox(height: 16),
             _buildEpicGrid(),
             
             const SizedBox(height: 32),
             _buildSectionHeader('Daily Wonders', '2/70', AppColors.primary, AppColors.primary.withOpacity(0.1), icon: Icons.rocket_launch),
             const SizedBox(height: 16),
             _buildDailyGrid(),
             
             const SizedBox(height: 80), // Padding for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String count, Color color, Color bg, {IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if(icon != null) ...[
              Icon(icon, color: color),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                 Text('Subtitle here', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        )
      ],
    );
  }

  Widget _buildLegendaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.yellow.shade200, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 8), blurRadius: 0)
        ]
      ),
      child: Column(
        children: [
          Container(
             height: 200,
             decoration: const BoxDecoration(
               borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
               image: DecorationImage(
                 image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuBB7DDpqCVINTclN506YhuKvG_zlyiendZKuy6GyJzgNV9TbzUsVGR2r1RBH6da4Rv35i66JZLcj0oBeSO9HFMuCsYdL9zpdMMBjnp9jH-ipl6B7DuJJn5vmCS4KoA7i9HzKkSfNueIBzlqZVYvDBLRsZ0YyIBzp1kBnvdyThD81dreuDLFiK5VQl-kIBc9sDYRdHHH_GO_WL_c8xC8ciUiFtbjgM6knWENSyqh8jYYCWWaOsQdoYan7Py2axQGgDtRCmQVPbOGGz8'),
                 fit: BoxFit.cover,
               )
             ),
             child: Stack(
               children: [
                 Container(
                   decoration: BoxDecoration(
                     gradient: LinearGradient(
                       begin: Alignment.bottomCenter,
                       end: Alignment.topCenter,
                       colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                       stops: const [0.0, 0.6]
                     )
                   ),
                 ),
                 Positioned(
                   top: 16, right: 16,
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                     decoration: BoxDecoration(color: Colors.yellow.shade700, borderRadius: BorderRadius.circular(12)),
                     child: const Text('LEGENDARY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                   ),
                 ),
                 const Positioned(
                   bottom: 16, left: 16,
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('Astronaut', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                       Text('Master of the Stars', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                     ],
                   ),
                 ),
                 Positioned(
                   bottom: 16, right: 16,
                   child: Icon(Icons.workspace_premium, color: Colors.yellow.shade700, size: 36),
                 )
               ],
             ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: 0.9,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade100,
                      color: Colors.yellow.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('90%', style: TextStyle(color: Colors.yellow.shade700, fontWeight: FontWeight.w900, fontSize: 12))
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEpicGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.8,
      children: [
        _buildEpicCard('Galaxy', Colors.purple, 0.65),
        _buildLockedCard(),
      ],
    );
  }

  Widget _buildEpicCard(String name, Color color, double progress) {
     return Container(
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: color.withOpacity(0.3)),
         boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), offset: const Offset(0, 4), blurRadius: 0)
         ]
       ),
       child: Column(
         children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  image: const DecorationImage(
                    image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuC2kLsHNVr-eSF67voNY-B8JpHkvPw5FGTdglHSibzaVsaoRoyxRvfrtndP0HVSwz2GHlabOQiKevGZY5PYWDDfqfNbmEZXj2qRWhdpfvQ1DZqrdNItnrpix8jpQosPah6WiGJGnFDXSdfhAzG-ces-WTPItw81TAwnVd9YdVuHmwGj9PNVnL2YWAOtqLal8yaDarHDErCAjgj5jT_dOBSzQ97yS2JDS71PlK5jbd9Riyh-YbntjoyC_bPID61RvgLXmfq3Qy5P7kE'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                           colors: [color.withOpacity(0.8), Colors.transparent], 
                           begin: Alignment.bottomCenter, end: Alignment.center
                        )
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
                    ),
                     Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                        child: const Text('EPIC', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                         value: progress,
                         backgroundColor: Colors.grey.shade100,
                         color: color,
                         minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(progress*100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
                ],
              ),
            )
         ],
       ),
     );
  }

  Widget _buildLockedCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, color: Colors.grey.shade300, size: 32),
            const SizedBox(height: 8),
            Text('LOCKED EPIC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyGrid() {
    return GridView.count(
       shrinkWrap: true,
       physics: const NeverScrollableScrollPhysics(),
       crossAxisCount: 3,
       mainAxisSpacing: 12,
       crossAxisSpacing: 12,
       children: [
          _buildDailyItem('Rocket', 'https://lh3.googleusercontent.com/aida-public/AB6AXuA3a86LhNSqb45XQvVfG6t0xC1hlhFXbukd1NmzdKNlEQ-j3rBfUiLiCYiyk-EVrVAUgXdMlqqMUkJIsYlo3mO3pVNAbLLmJsQhpfTD2kbtavQAx5VZzcUs4L4Ew52LEIaW6k_pMNi4IxssbFAosbQ4kT3qEDgrperGIZstlgtAYJaukl4Zb4g3YxtLLedJcKfYAo6ATCWlPTdoF3mDWXFC8WzfechewR7m69kNSIRxxHEn8k4TPsHBwUlDj4X5kqkwcZORp3QBot8'),
          _buildDailyItem('Planet', 'https://lh3.googleusercontent.com/aida-public/AB6AXuBayv9QG1-oo0f_ttz7GsCnGIpiRc0oM5oI-aPXyEMXfICkba747TQ_mOUmHvhk8kjGAhX1vNcbLcM2uoqFDeTw09dpe0I-h7toj4tLdDYZeM3TvaR549jbeE4XYFYVwM2Yg-Szgs_p4l362lUFRdEg1CzQF9JErEQtNvX8kKzDYjvbmXFn-FCdQoHNdAn1FD_Oo67vu0OgT6z1ANgu1iAaDOQLu6YwUkTxWwEQMRHktHhEAXhdQuJtWL9PTbQJDf2rrU2dUC3VY98'),
          _buildLockedDaily(),
          _buildLockedDaily(),
          _buildLockedDaily(),
          _buildLockedDaily(),
       ],
    );
  }

  Widget _buildDailyItem(String name, String url) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0,2))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      alignment: Alignment.bottomCenter,
       child: Container(
         width: double.infinity,
         padding: const EdgeInsets.all(4),
         decoration: BoxDecoration(
           gradient: LinearGradient(colors: [Colors.black.withOpacity(0.6), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.center)
         ),
         child: Text(name.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
       ),
    );
  }

  Widget _buildLockedDaily() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Icon(Icons.lock, color: Colors.grey.shade300, size: 20),
      ),
    );
  }
}
