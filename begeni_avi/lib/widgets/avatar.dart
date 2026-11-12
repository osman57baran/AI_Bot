import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

const _palette = [AppColors.pink, AppColors.cyan, AppColors.yellow, AppColors.green, Color(0xFFB388FF), Color(0xFFFF8A65)];

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url = '', this.size = 44, this.ring});

  final String name;
  final String url;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.hashCode.abs() % _palette.length];
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final fallback = Container(
      color: color,
      alignment: Alignment.center,
      child: Text(letter, style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.w900, color: AppColors.bg)),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring != null ? 3 : 0),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
      child: ClipOval(
        child: url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
