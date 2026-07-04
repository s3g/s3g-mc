{
    "patcher": {
        "fileversion": 1,
        "appversion": {
            "major": 9,
            "minor": 1,
            "revision": 4,
            "architecture": "x64",
            "modernui": 1
        },
        "classnamespace": "box",
        "rect": [ 269.0, 92.0, 1180.0, 760.0 ],
        "boxes": [
            {
                "box": {
                    "id": "obj-2",
                    "maxclass": "toggle",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "int" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 682.0, 6.0, 24.0, 24.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-title",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 20.0, 16.0, 420.0, 20.0 ],
                    "text": "s3g-mc Displacement Score Jitter Bridge"
                }
            },
            {
                "box": {
                    "id": "obj-drop",
                    "maxclass": "dropfile",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "" ],
                    "patching_rect": [ 20.0, 48.0, 126.0, 36.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-readprepend",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 20.0, 94.0, 80.0, 22.0 ],
                    "text": "prepend read"
                }
            },
            {
                "box": {
                    "id": "obj-play",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 160.0, 48.0, 35.0, 22.0 ],
                    "text": "play"
                }
            },
            {
                "box": {
                    "id": "obj-stop",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 200.0, 48.0, 35.0, 22.0 ],
                    "text": "stop"
                }
            },
            {
                "box": {
                    "id": "obj-reset",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 240.0, 48.0, 42.0, 22.0 ],
                    "text": "reset"
                }
            },
            {
                "box": {
                    "id": "obj-loop",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 435.0, 37.0, 112.0, 22.0 ],
                    "text": "playbackmode loop"
                }
            },
            {
                "box": {
                    "id": "obj-pal",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 435.0, 59.8, 149.0, 22.0 ],
                    "text": "playbackmode palindrome"
                }
            },
            {
                "box": {
                    "id": "obj-speed1",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 435.0, 82.6, 55.0, 22.0 ],
                    "text": "speed 1"
                }
            },
            {
                "box": {
                    "id": "obj-speed2",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 435.0, 105.39999999999999, 55.0, 22.0 ],
                    "text": "speed 2"
                }
            },
            {
                "box": {
                    "id": "obj-geom-sphere",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 435.0, 128.2, 112.0, 22.0 ],
                    "text": "geommode sphere"
                }
            },
            {
                "box": {
                    "id": "obj-geom-map",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 434.0, 151.0, 95.0, 22.0 ],
                    "text": "geommode map"
                }
            },
            {
                "box": {
                    "id": "obj-toggle",
                    "maxclass": "toggle",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "int" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 160.0, 112.0, 24.0, 24.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-metro",
                    "maxclass": "newobj",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "bang" ],
                    "patching_rect": [ 190.0, 113.0, 72.0, 22.0 ],
                    "text": "qmetro 16"
                }
            },
            {
                "box": {
                    "id": "obj-tick",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 265.0, 113.0, 30.0, 22.0 ],
                    "text": "tick"
                }
            },
            {
                "box": {
                    "id": "obj-scrub-label",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 20.0, 188.0, 52.0, 20.0 ],
                    "text": "scrub"
                }
            },
            {
                "box": {
                    "id": "obj-scrub-slider",
                    "maxclass": "slider",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "parameter_enable": 0,
                    "patching_rect": [ 74.0, 188.0, 226.0, 20.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-scrub-scale",
                    "maxclass": "newobj",
                    "numinlets": 6,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 310.0, 188.0, 112.0, 22.0 ],
                    "text": "scale 0 127 0. 1."
                }
            },
            {
                "box": {
                    "id": "obj-scrub-prepend",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 432.0, 188.0, 99.0, 22.0 ],
                    "text": "prepend setnorm"
                }
            },
            {
                "box": {
                    "filename": "displacement_score_jitter_player_v8.js",
                    "id": "obj-player",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 7,
                    "outlettype": [ "", "", "", "", "", "", "" ],
                    "patching_rect": [ 20.0, 156.0, 248.0, 22.0 ],
                    "saved_object_attributes": {
                        "parameter_enable": 0
                    },
                    "text": "v8 displacement_score_jitter_player_v8.js",
                    "textfile": {
                        "filename": "displacement_score_jitter_player_v8.js",
                        "flags": 0,
                        "embed": 0,
                        "autowatch": 1
                    }
                }
            },
            {
                "box": {
                    "id": "obj-world",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 3,
                    "outlettype": [ "jit_matrix", "bang", "" ],
                    "patching_rect": [ 720.0, 48.0, 443.0, 22.0 ],
                    "text": "jit.world ds_displacement @floating 1 @fsaa 1 @erase_color 0.035 0.035 0.035 1"
                }
            },
            {
                "box": {
                    "id": "obj-handle",
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "" ],
                    "patching_rect": [ 720.0, 80.0, 163.0, 22.0 ],
                    "text": "jit.gl.handle ds_displacement"
                }
            },
            {
                "box": {
                    "id": "obj-camera",
                    "linecount": 2,
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "jit_gl_texture", "" ],
                    "patching_rect": [ 895.0, 112.0, 355.0, 35.0 ],
                    "text": "jit.gl.camera ds_displacement @position 0. 0. 3.4 @lookat 0. 0. 0. @locklook 1"
                }
            },
            {
                "box": {
                    "id": "obj-view-front",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 720.0, 6.0, 122.0, 22.0 ],
                    "text": "position 0. 0. 3.4"
                }
            },
            {
                "box": {
                    "id": "obj-view-top",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 848.0, 6.0, 122.0, 22.0 ],
                    "text": "position 0. 3.4 0.01"
                }
            },
            {
                "box": {
                    "id": "obj-view-side",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 976.0, 6.0, 122.0, 22.0 ],
                    "text": "position 3.4 0. 0.01"
                }
            },
            {
                "box": {
                    "id": "obj-view-34",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 1104.0, 6.0, 132.0, 22.0 ],
                    "text": "position 2.2 1.5 3.2"
                }
            },
            {
                "box": {
                    "id": "obj-view-zoom",
                    "maxclass": "message",
                    "numinlets": 2,
                    "numoutlets": 1,
                    "outlettype": [ "" ],
                    "patching_rect": [ 1242.0, 6.0, 130.0, 22.0 ],
                    "text": "position 0. 0. 5.2"
                }
            },
            {
                "box": {
                    "id": "obj-sphere",
                    "linecount": 2,
                    "maxclass": "newobj",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "", "" ],
                    "patching_rect": [ 720.0, 114.0, 548.0, 35.0 ],
                    "text": "jit.gl.gridshape ds_displacement @shape sphere @scale 1.02 1.02 1.02 @color 0.18 0.22 0.24 0.22 @lighting_enable 0 @poly_mode 1 1 @blend_enable 1"
                }
            },
            {
                "box": {
                    "id": "obj-heat-pwindow",
                    "maxclass": "jit.pwindow",
                    "numinlets": 1,
                    "numoutlets": 2,
                    "outlettype": [ "jit_matrix", "" ],
                    "patching_rect": [ 20.0, 246.0, 520.0, 166.0 ],
                    "sync": 1
                }
            },
            {
                "box": {
                    "id": "obj-heat-label",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 20.0, 224.0, 260.0, 20.0 ],
                    "text": "heatmap matrix"
                }
            },
            {
                "box": {
                    "id": "obj-heat-hot",
                    "maxclass": "comment",
                    "numinlets": 1,
                    "numoutlets": 0,
                    "patching_rect": [ 720.0, 246.0, 420.0, 20.0 ]
                }
            },
            {
                "box": {
                    "id": "obj-source",
                    "linecount": 2,
                    "maxclass": "newobj",
                    "numinlets": 9,
                    "numoutlets": 2,
                    "outlettype": [ "", "" ],
                    "patching_rect": [ 720.0, 246.0, 405.0, 35.0 ],
                    "text": "jit.gl.mesh ds_displacement @draw_mode points @point_size 6 @color 0.24 0.68 0.82 0.5 @blend_enable 1"
                }
            },
            {
                "box": {
                    "id": "obj-lines",
                    "linecount": 2,
                    "maxclass": "newobj",
                    "numinlets": 9,
                    "numoutlets": 2,
                    "outlettype": [ "", "" ],
                    "patching_rect": [ 720.0, 278.0, 392.0, 35.0 ],
                    "text": "jit.gl.mesh ds_displacement @draw_mode lines @line_width 2 @color 1. 0.54 0.18 0.72 @blend_enable 1"
                }
            },
            {
                "box": {
                    "id": "obj-active",
                    "maxclass": "newobj",
                    "numinlets": 9,
                    "numoutlets": 2,
                    "outlettype": [ "", "" ],
                    "patching_rect": [ 720.0, 310.0, 575.0, 22.0 ],
                    "text": "jit.gl.mesh ds_displacement @draw_mode points @point_size 13 @color 1. 0.68 0.28 1. @blend_enable 1"
                }
            }
        ],
        "lines": [
            {
                "patchline": {
                    "destination": [ "obj-world", 0 ],
                    "source": [ "obj-2", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-readprepend", 0 ],
                    "source": [ "obj-drop", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-geom-map", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-geom-sphere", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-active", 0 ],
                    "order": 0,
                    "source": [ "obj-handle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-lines", 0 ],
                    "order": 1,
                    "source": [ "obj-handle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-source", 0 ],
                    "order": 2,
                    "source": [ "obj-handle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-sphere", 0 ],
                    "order": 3,
                    "source": [ "obj-handle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-loop", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-tick", 0 ],
                    "source": [ "obj-metro", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-pal", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-play", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-active", 0 ],
                    "source": [ "obj-player", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-camera", 0 ],
                    "source": [ "obj-player", 4 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-heat-pwindow", 0 ],
                    "source": [ "obj-player", 3 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-lines", 0 ],
                    "source": [ "obj-player", 2 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-source", 0 ],
                    "source": [ "obj-player", 1 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-readprepend", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-reset", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-scrub-prepend", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-scrub-prepend", 0 ],
                    "source": [ "obj-scrub-scale", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-scrub-scale", 0 ],
                    "source": [ "obj-scrub-slider", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-speed1", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-speed2", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-stop", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-player", 0 ],
                    "source": [ "obj-tick", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-metro", 0 ],
                    "source": [ "obj-toggle", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-camera", 0 ],
                    "source": [ "obj-view-34", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-camera", 0 ],
                    "source": [ "obj-view-front", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-camera", 0 ],
                    "source": [ "obj-view-side", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-camera", 0 ],
                    "source": [ "obj-view-top", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-camera", 0 ],
                    "source": [ "obj-view-zoom", 0 ]
                }
            },
            {
                "patchline": {
                    "destination": [ "obj-handle", 0 ],
                    "source": [ "obj-world", 1 ]
                }
            }
        ],
        "autosave": 0,
        "toolbaradditions": [ "Data Knot", "Vizzie" ]
    }
}