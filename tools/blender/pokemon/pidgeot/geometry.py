"""Malha autoral de ave: volumes por anéis e penas com espessura e nervura."""
import math
from mathutils import Vector

BROWN, CREAM, DARK, GOLD, RED = range(5)


class Geometry:
    def __init__(self):
        self.vertices = []
        self.faces = []
        self.materials = []
        self.weights = []

    def vertex(self, point, bone):
        self.vertices.append(tuple(point))
        self.weights.append({bone: 1.0})
        return len(self.vertices) - 1

    def face(self, ids, material):
        self.faces.append(tuple(ids))
        self.materials.append(material)

    def rings(self, profiles, material, bone, sides=12):
        """Volumes transversais suavemente variados, fechados nas extremidades."""
        start = len(self.vertices)
        for index, (center, rx, ry) in enumerate(profiles):
            for side in range(sides):
                angle = math.tau * side / sides
                asymmetry = 1 + .026 * math.sin(index * 2 + side * 1.7)
                point = (center[0] + math.cos(angle)*rx*asymmetry,
                         center[1] + math.sin(angle)*ry*asymmetry, center[2])
                self.vertex(point, bone)
        for ring in range(len(profiles)-1):
            for side in range(sides):
                a = start + ring*sides + side
                b = start + ring*sides + (side+1)%sides
                c = start + (ring+1)*sides + (side+1)%sides
                d = start + (ring+1)*sides + side
                self.face((a,b,c,d), material)
        self.face(tuple(start + i for i in reversed(range(sides))), material)
        last = start + (len(profiles)-1)*sides
        self.face(tuple(last + i for i in range(sides)), material)

    def tube(self, points, radii, material, bone, sides=7):
        start = len(self.vertices)
        for i, position in enumerate(points):
            p = Vector(position)
            tangent = Vector(points[min(i+1,len(points)-1)]) - Vector(points[max(0,i-1)])
            tangent.normalize()
            side = tangent.cross(Vector((0,0,1)))
            if side.length < .001:
                side = tangent.cross(Vector((0,1,0)))
            side.normalize()
            up = side.cross(tangent).normalized()
            for j in range(sides):
                theta = math.tau*j/sides
                self.vertex(p + radii[i]*(math.cos(theta)*side+math.sin(theta)*up), bone)
        for i in range(len(points)-1):
            for j in range(sides):
                a = start+i*sides+j
                b = start+i*sides+(j+1)%sides
                c = start+(i+1)*sides+(j+1)%sides
                d = start+(i+1)*sides+j
                self.face((a,b,c,d), material)
        self.face(tuple(start+j for j in reversed(range(sides))), material)
        self.face(tuple(start+(len(points)-1)*sides+j for j in range(sides)), material)

    def feather(self, root, tip, width, material, bone):
        """Pena lenticular de seis vértices; possui frente, verso e borda."""
        p = Vector(root)
        q = Vector(tip)
        direction = (q-p).normalized()
        sideways = direction.cross(Vector((0,1,0))).normalized()
        if sideways.length < .001:
            sideways = Vector((1,0,0))
        middle = p.lerp(q, .47)
        ridge = Vector((0,.025, .012))
        coords = [p, middle+sideways*width, q, middle-sideways*width,
                  middle+ridge, middle-ridge]
        ids = [self.vertex(value, bone) for value in coords]
        for polygon in ((0,1,4),(1,2,4),(2,3,4),(3,0,4),
                        (1,0,5),(2,1,5),(3,2,5),(0,3,5)):
            self.face([ids[k] for k in polygon], material)

    def wing(self, sign):
        suffix = "l" if sign < 0 else "r"
        upper = "wing_upper_" + suffix
        outer = "wing_outer_" + suffix
        shoulder = (sign*.22,-.015,1.01)
        elbow = (sign*.72,-.17,1.16)
        wrist = (sign*1.26,-.29,1.15)
        self.tube((shoulder,(sign*.43,-.11,1.12),elbow),(.105,.095,.075),BROWN,upper,9)
        self.tube((elbow,(sign*.96,-.24,1.19),wrist),(.08,.07,.035),BROWN,outer,9)
        # Sobreposição escalonada cria bordo serrilhado e sombra própria.
        for i in range(5):
            x = .34+i*.145
            root = (sign*x,-.12-i*.025,1.10+i*.015)
            tip = (sign*(x+.18),-.34-i*.018,.58+i*.045)
            self.feather(root,tip,.095-i*.005,BROWN,upper if i<3 else outer)
        for i in range(7):
            x = .72+i*.085
            root = (sign*x,-.21-i*.012,1.17-i*.006)
            tip = (sign*(x+.18+i*.017),-.38-i*.045,.67+i*.06)
            self.feather(root,tip,.080-i*.004,CREAM if i%3==0 else BROWN,outer)
        self.feather(wrist,(sign*1.58,-.39,1.09),.07,BROWN,outer)

    def build(self):
        # Corpo em gota, peito dianteiro claro e pescoço ascendente.
        self.rings([((0,-.13,.32),.10,.12),((0,-.11,.55),.26,.28),
                    ((0,-.07,.78),.30,.29),((0,.01,1.01),.24,.24),
                    ((0,.08,1.16),.13,.15)],BROWN,"body",16)
        self.rings([((0,.16,.36),.04,.028),((0,.20,.58),.15,.038),
                    ((0,.205,.82),.19,.045),((0,.18,1.07),.12,.030)],CREAM,"body",12)
        self.rings([((0,.07,1.04),.11,.12),((0,.11,1.20),.14,.15),
                    ((0,.17,1.31),.20,.18),((0,.20,1.36),.19,.17),
                    ((0,.21,1.39),.09,.10)],BROWN,"head",14)
        # Bico robusto, afilado à frente (+Y no Blender = -Z no Godot).
        self.tube([(0,.30,1.25),(0,.44,1.22),(0,.55,1.18)],
                  [.125,.10,.017],GOLD,"head",9)
        self.tube([(0,.37,1.195),(0,.47,1.175),(0,.51,1.17)],
                  [.079,.065,.012],DARK,"head",7)
        for sign in (-1,1):
            self.tube([(sign*.145,.265,1.335),(sign*.167,.300,1.337)],
                      [.046,.033],CREAM,"head",8)
            self.tube([(sign*.15,.30,1.34),(sign*.173,.333,1.34)],
                      [.025,.018],DARK,"head",8)
            # Crista longa em duas camadas; a ponta define a altura de 1,50 m.
            for i in range(3):
                root = (sign*(.03+i*.055), .11-i*.018, 1.36)
                tip = (sign*(.08+i*.075), -.33-i*.115, 1.50-i*.055)
                self.feather(root,tip,.060,RED if i<2 else GOLD,"head")
            self.wing(sign)
            suffix="l" if sign<0 else "r"
            hip=(sign*.145,-.065,.42)
            self.tube([hip,(sign*.18,.025,.25),(sign*.17,.09,.11)],
                      [.085,.065,.046],BROWN,"leg_"+suffix,9)
            self.tube([(sign*.17,.09,.11),(sign*.17,.20,.055)],
                      [.047,.038],GOLD,"foot_"+suffix,8)
            for toe in (-1,0,1):
                x=sign*.17+toe*.045
                self.tube([(x,.19,.052),(x+toe*.016,.31,.006)],
                          [.021,.009],GOLD,"foot_"+suffix,6)
        # Fan de cauda em camadas, sem cone/cilindro na silhueta.
        self.tube([(0,-.18,.49),(0,-.40,.41),(0,-.64,.39)],
                  [.13,.105,.055],BROWN,"tail",9)
        for i in range(-3,4):
            self.feather((i*.027,-.47,.41),(i*.09,-1.06+abs(i)*.048,.33+abs(i)*.016),
                         .060,CREAM if i%2==0 else BROWN,"tail")
        return self
