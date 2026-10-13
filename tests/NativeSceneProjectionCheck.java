import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;
import java.util.regex.*;
public class NativeSceneProjectionCheck {
 static Class<?> scene,mat,vec;
 static Object call(Object o,String n,Class<?>[] p,Object... a)throws Exception{return o.getClass().getMethod(n,p).invoke(o,a);}
 static float proj(Object s,String axis,float x,float y,float z)throws Exception{return (Float)call(s,"sceneToUI"+axis,new Class[]{float.class,float.class,float.class},x,y,z);}
 public static void main(String[] args)throws Exception{
  scene=Class.forName("zombie.vehicles.UI3DScene"); mat=Class.forName("org.joml.Matrix4f"); vec=Class.forName("org.joml.Vector3f");
  Object s=scene.getConstructor(Class.forName("se.krka.kahlua.vm.KahluaTable")).newInstance(new Object[]{null});
  call(s,"fromLua1",new Class[]{String.class,Object.class},"setMaxZoom",20d);
  List<float[]> points=new ArrayList<>(); List<String> names=new ArrayList<>();
  String file=Files.readString(Path.of(args[0])); String body=file.substring(file.indexOf("model AK74u_long"),file.indexOf("model AK9"));
  Matcher m=Pattern.compile("attachment\\s+(\\w+)\\s*\\{\\s*offset\\s*=\\s*([-.0-9]+)\\s+([-.0-9]+)\\s+([-.0-9]+)").matcher(body);
  double l=10,r=-10,b=10,t=-10;
  while(m.find())if(!m.group(1).equals("world")){float[] p={Float.parseFloat(m.group(2)),Float.parseFloat(m.group(3)),Float.parseFloat(m.group(4))};points.add(p);names.add(m.group(1));l=Math.min(l,p[1]);r=Math.max(r,p[1]);b=Math.min(b,p[2]);t=Math.max(t,p[2]);}
  if(points.isEmpty())throw new AssertionError("No source sockets found");
  double len=r-l,rear=Math.max(.14,len*.35),front=Math.max(.07,len*.14),full=len+rear+front;
  l-=rear;r+=front;b-=Math.max(.11,full*.24);t+=Math.max(.11,full*.18);
  for(int[] size:new int[][]{{388,188},{300,200},{600,280}}){
   int w=size[0],h=size[1];call(s,"setWidth",new Class[]{double.class},(double)w);call(s,"setHeight",new Class[]{double.class},(double)h);
   call(s,"fromLua1",new Class[]{String.class,Object.class},"setZoom",13d);
   double ppu=w/1366d*Math.exp(2.6)*160/1.82;float scale=(float)Math.max(.05,Math.min(8,Math.min(w*.86/(full*ppu),h*.86/(Math.max(t-b,full*.47)*ppu))));
   float ty=(float)(-(b+t)/2*scale),tz=(float)((l+r)/2*scale);
   System.out.printf("SIZE %dx%d scale=%.6f ppu=%.6f tx=0 ty=%.6f tz=%.6f%n",w,h,scale,ppu,ty,tz);
   for(int i=0;i<points.size();i++){
    float[] p=points.get(i);float x=proj(s,"X",p[0]*scale,ty+p[2]*scale,tz-p[1]*scale),y=proj(s,"Y",p[0]*scale,ty+p[2]*scale,tz-p[1]*scale);
    double ex=w*.5+ppu*(tz-p[1]*scale),ey=h*.5-ppu*(ty+p[2]*scale);
    if(Math.abs(x-ex)>.001||Math.abs(y-ey)>.001)throw new AssertionError("native mismatch");
    if(w==388)System.out.printf("  %-14s raw %.4f %.4f %.4f => native %.3f %.3f ; old-flip %.3f%n",names.get(i),p[0],p[1],p[2],x,y,w-x);
   }
   for(int up:new int[]{1,-1})for(int direction:new int[]{1,-1})for(float[] p:new float[][]{{.12f,.4f,.03f},{-.12f,-.4f,-.03f}}){
    Object matrix=mat.getConstructor().newInstance(); call(matrix,"translation",new Class[]{float.class,float.class,float.class},0f,ty,tz);
    call(matrix,"rotateXYZ",new Class[]{float.class,float.class,float.class},-(float)Math.PI/2,up<0?(float)Math.PI:0f,direction<0?(float)Math.PI:0f);
    call(matrix,"scale",new Class[]{float.class},scale);Object v=vec.getConstructor(float.class,float.class,float.class).newInstance(p[0],p[1],p[2]);call(matrix,"transformPosition",new Class[]{vec},v);
    float wx=vec.getField("x").getFloat(v),wy=vec.getField("y").getFloat(v),wz=vec.getField("z").getFloat(v);
    if(Math.abs(wx-up*direction*p[0]*scale)>.0001||Math.abs(wy-(ty+up*p[2]*scale))>.0001||Math.abs(wz-(tz-direction*p[1]*scale))>.0001)throw new AssertionError("object axis mismatch");
   }
  }
  System.out.println("PASS actual UI3DScene projection + native JOML held-object transform: all 14 AK74u_long sockets, 3 dimensions, both forward and up signs, nonzero XYZ. No renderer or game session started.");
 }
}
