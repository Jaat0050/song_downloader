import 'package:flutter/material.dart';

const kNeuBackground = Color(0xFF252E3D);
const kNeuSurface = Color(0xFF2B3545);
const kNeuSurfaceDeep = Color(0xFF273141);
const kNeuSurfaceLight = Color(0xFF303B4C);
const kNeuAccent = Color(0xFFFF6B5F);
const kNeuAccentSoft = Color(0xFFFF8277);

class NeuSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  const NeuSurface({super.key,required this.child,this.padding=const EdgeInsets.all(16),this.borderRadius=const BorderRadius.all(Radius.circular(20))});
  @override Widget build(BuildContext context)=>Container(padding:padding,decoration:BoxDecoration(color:kNeuSurface,borderRadius:borderRadius,border:Border.all(color:Colors.white.withValues(alpha:.055)),boxShadow:[BoxShadow(color:const Color(0xFF17202D).withValues(alpha:.82),offset:const Offset(8,8),blurRadius:16),BoxShadow(color:const Color(0xFF3D4A5E).withValues(alpha:.72),offset:const Offset(-6,-6),blurRadius:14)]),child:child);
}

class NeuButton extends StatefulWidget {
  final Widget child; final VoidCallback? onPressed; final EdgeInsetsGeometry padding;
  const NeuButton({super.key,required this.child,this.onPressed,this.padding=const EdgeInsets.symmetric(horizontal:20,vertical:15)});
  @override State<NeuButton> createState()=>_NeuButtonState();
}
class _NeuButtonState extends State<NeuButton>{bool _pressed=false;
  @override Widget build(BuildContext context)=>GestureDetector(onTapDown:widget.onPressed==null?null:(_)=>setState(()=>_pressed=true),onTapCancel:()=>setState(()=>_pressed=false),onTapUp:widget.onPressed==null?null:(_){setState(()=>_pressed=false);widget.onPressed!();},child:AnimatedContainer(duration:const Duration(milliseconds:120),padding:widget.padding,decoration:BoxDecoration(color:widget.onPressed==null?kNeuSurfaceDeep:kNeuAccent,borderRadius:BorderRadius.circular(17),border:Border.all(color:widget.onPressed==null?Colors.white.withValues(alpha:.04):kNeuAccentSoft.withValues(alpha:.6)),boxShadow:_pressed?[BoxShadow(color:const Color(0xFF17202D).withValues(alpha:.65),offset:const Offset(3,3),blurRadius:7)]:[BoxShadow(color:const Color(0xFF17202D).withValues(alpha:.8),offset:const Offset(6,6),blurRadius:12),BoxShadow(color:Colors.white.withValues(alpha:.12),offset:const Offset(-4,-4),blurRadius:9)]),child:DefaultTextStyle.merge(style:TextStyle(color:widget.onPressed==null?Colors.white38:Colors.white,fontWeight:FontWeight.w700),child:Center(child:widget.child))));}
}

class NeuIconButton extends StatelessWidget {
  final IconData icon; final VoidCallback? onPressed; final bool active;
  const NeuIconButton({super.key,required this.icon,this.onPressed,this.active=false});
  @override Widget build(BuildContext context)=>Container(decoration:BoxDecoration(color:kNeuSurfaceLight,shape:BoxShape.circle,border:Border.all(color:Colors.white.withValues(alpha:.045)),boxShadow:[BoxShadow(color:const Color(0xFF17202D).withValues(alpha:.78),offset:const Offset(5,5),blurRadius:10),BoxShadow(color:const Color(0xFF3D4A5E).withValues(alpha:.62),offset:const Offset(-3,-3),blurRadius:8)]),child:IconButton(onPressed:onPressed,icon:Icon(icon),color:active?kNeuAccentSoft:Colors.white70));
}
