"""Malha anatômica estilizada em Blender Z-up, frente +Y (Godot −Z)."""
import math
from mathutils import Vector

ORANGE, SHADOW, CREAM, WING, EYE, CLAW, FLAME = range(7)


class Geometry:
    def __init__(self):
        self.vertices, self.faces, self.face_materials, self.weights = [], [], [], []

    def vertex(self, position, weights):
        self.vertices.append(tuple(position))
        self.weights.append(dict(weights))
        return len(self.vertices) - 1

    def face(self, indices, material):
        self.faces.append(tuple(indices))
        self.face_materials.append(material)

    def loft(self, rings, material, bones, sides=12, phase=0.0):
        """Anéis de seção elíptica com extremos fechados e pesos interpolados."""
        first = len(self.vertices)
        for index, (center, rx, ry) in enumerate(rings):
            angle_offset = phase + index * .035
            for side in range(sides):
                angle = math.tau * side / sides + angle_offset
                # Pequena assimetria controlada preserva o caráter modelado.
                k = 1.0 + .045 * math.sin(side * 2.3 + index * 1.7)
                c = Vector(center)
                point = (c.x + math.cos(angle) * rx * k,
                         c.y + math.sin(angle) * ry * k, c.z)
                t = index / max(1, len(rings) - 1)
                low, high = bones
                self.vertex(point, {low: 1.0-t, high: t} if low != high else {low: 1.0})
        for ring in range(len(rings)-1):
            for side in range(sides):
                a=first+ring*sides+side; b=first+ring*sides+(side+1)%sides
                c=first+(ring+1)*sides+(side+1)%sides; d=first+(ring+1)*sides+side
                self.face((a,b,c,d), material)
        self.face(tuple(first+s for s in reversed(range(sides))), material)
        self.face(tuple(first+(len(rings)-1)*sides+s for s in range(sides)), material)

    def tube(self, points, radii, material, bones, sides=9):
        start=len(self.vertices)
        for i, point in enumerate(points):
            p=Vector(point)
            tangent=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
            side=tangent.cross(Vector((0,0,1)))
            if side.length_squared < .0001: side=tangent.cross(Vector((0,1,0)))
            side.normalize(); up=side.cross(tangent).normalized()
            t=i/max(1,len(points)-1); low,high=bones
            weights={low:1.0-t,high:t} if low!=high else {low:1.0}
            for j in range(sides):
                theta=math.tau*j/sides+i*.08
                self.vertex(p+(side*math.cos(theta)+up*math.sin(theta))*radii[i],weights)
        for i in range(len(points)-1):
            for j in range(sides):
                a=start+i*sides+j; b=start+i*sides+(j+1)%sides
                c=start+(i+1)*sides+(j+1)%sides; d=start+(i+1)*sides+j
                self.face((a,b,c,d),material)
        self.face(tuple(start+j for j in reversed(range(sides))),material)
        self.face(tuple(start+(len(points)-1)*sides+j for j in range(sides)),material)

    def wing(self, sign, bone):
        """Membrana recortada com raiz, cotovelo, nervuras e espessura na borda."""
        p=[(.27,-.12,1.22),(.61,-.23,1.43),(1.26,-.42,1.67),(1.49,-.52,1.58),
           (1.24,-1.08,1.16),(.96,-.92,1.30),(.74,-.98,.99),(.54,-.69,1.15),(.36,-.42,.95)]
        p=[(sign*x,y,z) for x,y,z in p]
        ids=[self.vertex(v,{bone:1.0}) for v in p]
        # Quatro painéis com borda inferior recortada: leitura clara em 3/4 e dorso.
        for polygon in [(0,1,8),(1,7,8),(1,2,5,7),(2,3,4,5),(5,6,7)]:
            self.face([ids[i] for i in polygon],WING)
        for a,b,r in [(0,1,.055),(1,2,.045),(2,3,.025),(1,7,.022),(2,5,.020),(5,6,.019)]:
            self.tube([p[a],p[b]],[r,r*.55],SHADOW,(bone,bone),6)

    def build(self):
        # Corpo único em camadas de perfil; áreas da barriga mudam a superfície,
        # mantendo sobreposição discreta nas juntas que realmente articulam.
        self.loft([((0,-.04,.42),.16,.18),((0,-.07,.60),.26,.25),((0,-.06,.85),.30,.27),
                   ((0,-.01,1.08),.27,.25),((0,.02,1.25),.22,.20),((0,.06,1.33),.12,.13)],ORANGE,("pelvis","chest"),16)
        self.loft([((0,.200,.50),.08,.025),((0,.210,.76),.16,.035),((0,.217,1.01),.185,.04),
                   ((0,.20,1.21),.12,.025)],CREAM,("pelvis","chest"),12)
        self.loft([((0,.06,1.22),.125,.13),((0,.13,1.36),.17,.16),((0,.20,1.45),.225,.19),
                   ((0,.25,1.53),.25,.205),((0,.29,1.59),.21,.18),((0,.31,1.62),.11,.10)],ORANGE,("neck","head"),16)
        self.loft([((0,.31,1.43),.16,.14),((0,.42,1.46),.20,.16),((0,.52,1.47),.19,.13),
                   ((0,.61,1.49),.14,.09)],ORANGE,("head","jaw"),14)
        self.tube([(0,.40,1.395),(0,.52,1.40),(0,.59,1.43)],[.13,.14,.08],SHADOW,("jaw","jaw"),8)
        for sign,suffix in [(-1,"l"),(1,"r")]:
            # Sobrancelha e olho alongado, narina pequena e dois chifres inclinados.
            self.tube([(sign*.115,.405,1.53),(sign*.15,.475,1.51)],[.066,.052],CLAW,("head","head"),9)
            self.tube([(sign*.122,.464,1.53),(sign*.15,.502,1.52)],[.032,.024],EYE,("head","head"),8)
            self.tube([(sign*.085,.40,1.59),(sign*.15,.45,1.565)],[.043,.030],ORANGE,("head","head"),7)
            self.tube([(sign*.077,.594,1.52),(sign*.083,.615,1.53)],[.015,.007],SHADOW,("jaw","jaw"),6)
            self.tube([(sign*.15,.18,1.57),(sign*.18,.08,1.67),(sign*.22,.02,1.69)],
                      [.065,.040,.006],ORANGE,("head","head"),8)
            # Braço curvado, antebraço e mão com três dedos distintos.
            self.tube([(sign*.255,.005,1.16),(sign*.38,.065,1.08),(sign*.42,.20,.96),
                       (sign*.43,.27,.89)],[.13,.115,.09,.08],ORANGE,("arm_"+suffix,"forearm_"+suffix),11)
            self.loft([((sign*.43,.28,.84),.075,.072),((sign*.44,.29,.91),.095,.095),
                       ((sign*.43,.27,.97),.066,.072)],ORANGE,("hand_"+suffix,"hand_"+suffix),9)
            for finger in [-1,0,1]:
                self.tube([(sign*.43+finger*.052,.35,.88),(sign*.43+finger*.055,.42,.86)],
                          [.028,.006],CLAW,("hand_"+suffix,"hand_"+suffix),6)
            # Coxa robusta, jarrete e pé apoiado, incluindo três dedos para frente.
            self.tube([(sign*.18,-.045,.55),(sign*.23,.00,.40),(sign*.24,.12,.27),
                       (sign*.23,.18,.14)],[.155,.145,.105,.095],ORANGE,("leg_"+suffix,"shin_"+suffix),14)
            self.loft([((sign*.23,.19,0),.11,.16),((sign*.23,.31,.07),.14,.21),
                       ((sign*.23,.41,.09),.105,.14)],ORANGE,("foot_"+suffix,"foot_"+suffix),10)
            for toe in [-1,0,1]:
                self.tube([(sign*.23+toe*.085,.40,.07),(sign*.23+toe*.088,.49,.045)],
                          [.035,.008],CLAW,("foot_"+suffix,"foot_"+suffix),6)
            self.wing(sign,"wing_"+suffix)
        # Cauda em arco único e afunilado; a chama lê separada da malha laranja.
        self.tube([(0,-.18,.62),(0,-.48,.56),(0,-.81,.51),(0,-1.10,.56),
                   (0,-1.36,.69),(0,-1.50,.86)],[.15,.145,.12,.09,.06,.04],
                  ORANGE,("tail","tail_tip"),12)
        self.tube([(0,-1.50,.86),(0,-1.56,1.01),(0,-1.50,1.18),(0,-1.46,1.29)],
                  [.12,.115,.068,.004],FLAME,("tail_tip","tail_tip"),9)
        for sign in (-1,1):
            self.tube([(sign*.035,-1.51,.89),(sign*.10,-1.55,1.03),(sign*.13,-1.49,1.17)],
                      [.065,.045,.003],FLAME,("tail_tip","tail_tip"),7)
        self.tube([(0,-1.53,.91),(0,-1.54,1.06),(0,-1.52,1.20)],
                  [.065,.047,.004],CREAM,("tail_tip","tail_tip"),7)
        return self
