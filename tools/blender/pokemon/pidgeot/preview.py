"""Renders Workbench rápidos para inspeção de silhueta e animação."""
import os
import bpy
from mathutils import Vector

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"../../../.."))
OUT=os.path.join(ROOT,"assets/models/pokemon/previews/pidgeot_golden")
VIEWS={
    "front":((0,3.8,1.6),(0,0,.78),"IDLE",1),
    "side":((3.6,.3,1.6),(0,0,.78),"IDLE",1),
    "three_quarter":((2.8,3.1,1.7),(0,0,.78),"IDLE",1),
    "rear":((0,-3.8,1.6),(0,0,.78),"IDLE",1),
    "walk":((2.8,3.1,1.7),(0,0,.78),"WALK",1),
    "run":((2.8,3.1,1.7),(0,0,.78),"RUN",1),
    "fly_up":((2.8,3.1,1.7),(0,0,.78),"FLY",1),
    "fly_down":((2.8,3.1,1.7),(0,0,.78),"FLY",13),
}


def main():
    os.makedirs(OUT,exist_ok=True)
    scene=bpy.context.scene
    scene.render.engine="BLENDER_WORKBENCH"
    scene.display.shading.color_type="MATERIAL"
    scene.display.shading.light="STUDIO"
    scene.display.shading.show_shadows=True
    scene.display.shading.show_cavity=True
    scene.render.resolution_x=640
    scene.render.resolution_y=640
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    cam_data=bpy.data.cameras.new("PIDGEOT_PREVIEW_CAMERA")
    camera=bpy.data.objects.new("PIDGEOT_PREVIEW_CAMERA",cam_data)
    scene.collection.objects.link(camera)
    cam_data.type="ORTHO"
    cam_data.ortho_scale=3.2
    scene.camera=camera
    arm=bpy.data.objects["PKM_PIDGEOT_ARMATURE"]
    arm.animation_data.use_nla=False
    for label,(position,target,action,frame) in VIEWS.items():
        arm.animation_data.action=bpy.data.actions["PKM_PIDGEOT_"+action]
        scene.frame_set(frame)
        camera.location=position
        camera.rotation_euler=(Vector(target)-camera.location).to_track_quat("-Z","Y").to_euler()
        scene.render.filepath=os.path.join(OUT,label+".png")
        bpy.ops.render.render(write_still=True)
        print("PIDGEOT_PREVIEW",label)


if __name__=="__main__":
    main()
