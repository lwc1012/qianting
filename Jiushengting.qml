import QtQuick
import QtQuick3D

Node {
    id: node

    Texture { id: tex_001_diff; source: "textures/001_1_diff.png" }
    Texture { id: tex_001_ddn; source: "textures/001_ddn.png" }
    Texture { id: tex_001_spec; source: "textures/001_spec.png" }

    Texture { id: tex_002_diff; source: "textures/002_diff.png" }
    Texture { id: tex_002_ddn; source: "textures/002_ddn.png" }
    Texture { id: tex_002_spec; source: "textures/002_spec.png" }

    Texture { id: tex_003_diff; source: "textures/003_1diff.png" }
    Texture { id: tex_003_ddn; source: "textures/003_ddn.png" }
    Texture { id: tex_003_spec; source: "textures/003_spec.png" }

    Texture { id: tex_004_diff; source: "textures/004_diff.png" }
    Texture { id: tex_004_ddn; source: "textures/004_ddn.png" }
    Texture { id: tex_004_spec; source: "textures/004_spec.png" }

    Texture { id: tex_logo; source: "textures/logo.png" }

    Texture { id: tex_mesh_diff; source: "textures/mesh_1diff.png" }
    Texture { id: tex_mesh_ddn; source: "textures/mesh_ddn.png" }
    Texture { id: tex_mesh_spec; source: "textures/mesh_spec.png" }

    Texture { id: tex_shengna_diff; source: "textures/shengna_1diff.png" }
    Texture { id: tex_shengna_ddn; source: "textures/shengna_ddn.png" }
    Texture { id: tex_shengna_spec; source: "textures/shengna_spec.png" }

    PrincipledMaterial {
        id: node001_material
        objectName: "001"
        roughness: 0.5243171453475952
        baseColorMap: tex_001_diff
        normalMap: tex_001_ddn
        specularMap: tex_001_spec
    }

    PrincipledMaterial {
        id: node002_material
        objectName: "002"
        roughness: 0.858578622341156
        baseColorMap: tex_002_diff
        normalMap: tex_002_ddn
        specularMap: tex_002_spec
    }

    PrincipledMaterial {
        id: node003_material
        objectName: "003"
        roughness: -0.3454342484474182
        baseColorMap: tex_003_diff
        normalMap: tex_003_ddn
        specularMap: tex_003_spec
    }

    PrincipledMaterial {
        id: node003_LuoJiangJiang_material
        objectName: "003_LuoJiangJiang"
        roughness: -0.3454342484474182
        baseColorMap: tex_003_diff
        normalMap: tex_003_ddn
        specularMap: tex_003_spec
    }

    PrincipledMaterial {
        id: node004_material
        objectName: "004"
        roughness: 0.800000011920929
        baseColorMap: tex_004_diff
        normalMap: tex_004_ddn
        specularMap: tex_004_spec
    }

    PrincipledMaterial {
        id: logo_material
        objectName: "Logo"
        roughness: -0.3454342484474182
        baseColorMap: tex_logo
    }

    PrincipledMaterial {
        id: mesh_1_material
        objectName: "mesh_1"
        roughness: -0.3454342484474182
        baseColorMap: tex_mesh_diff
        normalMap: tex_mesh_ddn
        specularMap: tex_mesh_spec
    }

    PrincipledMaterial {
        id: shengNa_material
        objectName: "ShengNa"
        roughness: 0.04863431677222252
        baseColorMap: tex_shengna_diff
        normalMap: tex_shengna_ddn
        specularMap: tex_shengna_spec
    }

    PrincipledMaterial {
        id: shengNa1_material
        objectName: "ShengNa1"
        roughness: 0.04863431677222252
        baseColorMap: tex_shengna_diff
        normalMap: tex_shengna_ddn
        specularMap: tex_shengna_spec
    }

    PrincipledMaterial {
        id: boLi_material
        objectName: "BoLi"
        baseColor: "#88000000" // 带透明度的黑色，前两位88是Alpha通道，实现半透明效果
        roughness: 0.04863431677222252
        transmissionFactor: 0.9
    }


    Node {
        id: rootNode
        objectName: "RootNode"
        Model {
            id: lr7
            objectName: "LR7"
            rotation: Qt.quaternion(-3.09086e-08, 3.09086e-08, 0.707107, 0.707107)
            source: "meshes/lr7_mesh.mesh"
            materials: [
                node003_material,
                node001_material,
                boLi_material,
                node002_material,
                logo_material,
                node004_material,
                mesh_1_material,
                node003_LuoJiangJiang_material,
                shengNa_material,
                shengNa1_material
            ]
        }
    }
}
