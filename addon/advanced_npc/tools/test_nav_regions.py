"""Geometry regressions using synthetic BSP hulls and analytic expectations."""
import math
from pathlib import Path
import struct
import tempfile
import unittest

from check_nav_regions import Bsp, EPSILON, certify, plane_height


def make_bsp(path, slope=0.0, ceiling=256.0, gap=None, wall=None):
    normal = (-slope/math.sqrt(1+slope*slope), 0.0, 1/math.sqrt(1+slope*slope))
    planes, point_nodes, clipnodes = [], [], []

    def hull(height, point=False):
        records = point_nodes if point else clipnodes
        radius = 0 if point else 16
        plane = len(planes)
        planes.append((*normal, height*normal[2]+radius*abs(normal[0]), 3))
        root = len(records)
        records.append(None)
        ceiling_plane = len(planes)
        planes.append((0., 0., -1., -ceiling+height, 3))
        air_branch = len(records)
        records.append((ceiling_plane, -1, -2))
        if wall is not None:
            wall_plane = len(planes)
            planes.append((-1., 0., 0., -wall+radius, 3))
            records[air_branch] = (ceiling_plane, len(records), -2)
            records.append((wall_plane, -1, -2))
        floor_branch = -2
        if gap:
            low_plane = len(planes)
            planes.append((1., 0., 0., gap[0]+radius, 0))
            high_plane = len(planes)
            planes.append((1., 0., 0., gap[1]-radius, 0))
            floor_branch = len(records)
            records.extend([(low_plane, floor_branch+1, -2), (high_plane, -2, -1)])
        records[root] = (plane, air_branch, floor_branch)
        return root

    point_head = hull(0, True)
    stand_head = hull(36)
    crouch_head = hull(18)
    lumps = [b'' for _ in range(15)]
    lumps[1] = b''.join(struct.pack('<4fi', *p) for p in planes)
    lumps[5] = b''.join(struct.pack('<i2h6h2H', *row, *([0]*8)) for row in point_nodes)
    lumps[9] = b''.join(struct.pack('<i2h', *row) for row in clipnodes)
    lumps[10] = b''.join(struct.pack('<ii6h2H4B', contents, -1, *([0]*12)) for contents in (-1,-2))
    lumps[14] = struct.pack('<9f7i', *([0.]*9), point_head, stand_head, stand_head, crouch_head, 0, 0, 0)
    offset = 4+15*8
    header = struct.pack('<i',30)
    for lump in lumps:
        header += struct.pack('<ii',offset,len(lump))
        offset += len(lump)
    path.write_bytes(header+b''.join(lumps))
    return normal


class NavigationRegionGeometryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name)/'fixture.bsp'

    def tearDown(self):
        self.temporary.cleanup()

    def scene(self, **options):
        normal = make_bsp(self.path, **options)
        return Bsp(self.path), normal

    def support(self, normal, x=0., crouched=False):
        # Independent analytic support for the expanded half-space, with the
        # collision epsilon projected vertically, as used by BSP hull tracing.
        return (x, 0., (-normal[0]*x+16*abs(normal[0])+EPSILON)/normal[2])

    def test_hull_trace_matches_analytic_ramp_intersection(self):
        bsp, normal = self.scene(slope=0.25)
        feet = self.support(normal, 128.)
        hit = bsp.trace(1,(128.,0.,feet[2]+36+1),(128.,0.,feet[2]+36-16))
        self.assertFalse(hit.start_solid)
        self.assertAlmostEqual(hit.end[2]-36,feet[2], places=5)
        self.assertEqual(hit.normal, tuple(bsp.planes[0][:3]))

    def test_flat_open_room_accepts_large_rectangle(self):
        bsp, normal = self.scene()
        self.assertEqual(certify(bsp,0,0,256,self.support(normal),normal),(True,'open'))

    def test_uniform_ramp_accepts_rectangle(self):
        bsp, normal = self.scene(slope=0.25)
        self.assertLess(normal[2],0.999)  # Previous rule rejected this support.
        self.assertEqual(certify(bsp,0,0,128,self.support(normal),normal),(True,'open'))

    def test_negative_coordinates_preserve_ramp_plane(self):
        bsp, normal = self.scene(slope=-0.25)
        self.assertEqual(certify(bsp,-2,-1,128,self.support(normal,-192.),normal),(True,'open'))

    def test_low_ceiling_does_not_reject_standing_floor(self):
        bsp, normal = self.scene(ceiling=80.)
        feet = self.support(normal)
        old = bsp.trace(0,(0.,0.,feet[2]+90.),(0.,0.,feet[2]-4.))
        self.assertTrue(old.start_solid)
        self.assertEqual(certify(bsp,0,0,128,feet,normal),(True,'open'))

    def test_crouch_clearance_is_distinct_from_standing_clearance(self):
        bsp, normal = self.scene(ceiling=48.)
        feet = self.support(normal)
        self.assertFalse(certify(bsp,0,0,128,feet,normal)[0])
        self.assertEqual(certify(bsp,0,0,128,feet,normal,True),(True,'open'))

    def test_hole_in_middle_cannot_be_certified_from_valid_endpoints(self):
        bsp, normal = self.scene(gap=(96.,160.))
        feet = self.support(normal)
        self.assertIsNotNone(bsp.floor(feet))
        self.assertIsNotNone(bsp.floor((256.,0.,feet[2])))
        self.assertEqual(certify(bsp,0,0,256,feet,normal),(False,'floor'))

    def test_wall_forces_subdivision_and_valid_siblings_survive(self):
        bsp, normal = self.scene(wall=160.)
        feet = self.support(normal)
        self.assertEqual(certify(bsp,0,0,256,feet,normal),(False,'hull'))
        children = [certify(bsp,i%2,i//2,128,feet,normal)[0] for i in range(4)]
        self.assertEqual(children,[True,False,True,False])

    def test_different_floor_layer_is_not_a_planar_interior(self):
        bsp, normal = self.scene()
        wrong_floor = (0.,0.,32.)
        self.assertIsNone(bsp.floor(wrong_floor))
        self.assertFalse(certify(bsp,0,0,128,wrong_floor,normal)[0])

    def test_plane_corners_are_not_a_horizontal_bounding_box(self):
        normal = (-0.2,0.3,math.sqrt(0.87))
        origin = (-256.,-128.,48.)
        for x,y in [(-256.,-128.),(-128.,-128.),(-128.,0.),(-256.,0.)]:
            z = plane_height(origin,normal,x,y)
            self.assertAlmostEqual(sum(normal[i]*([x,y,z][i]-origin[i]) for i in range(3)),0.)


if __name__ == '__main__':
    unittest.main()
