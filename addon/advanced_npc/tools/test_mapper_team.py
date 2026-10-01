"""Team identity/reservation/journal contracts from installed Pawn sources.

Evaluates actual source guards and selected assignment blocks with native
doubles. This does not compile Pawn or execute HLDS movement or its scheduler.
"""
import ast
from pathlib import Path
import re
import unittest

from test_mapper_contracts import body, conditions, predicate


# AMXX compiler/libpc300/sc2.c, sc_tokens: language keywords (not directives).
PAWN_RESERVED_WORDS = frozenset('''assert break case char const continue default
    defined do else enum exit for forward goto if native new operator public
    return sizeof sleep state static stock switch tagof while'''.split())


def reserved_parameters(source):
    """Check names in ordinary Pawn function declarations, without compiling."""
    source = re.sub(r'"(?:\^.|[^"\n])*"|//[^\n]*|/\*[\s\S]*?\*/',
                    lambda match: '\n'*match[0].count('\n'), source)
    declarations = re.finditer(
        r'(?m)^\s*(?:stock|public|native|forward)\s+(?:\w+:)?(\w+)\s*\(([^)]*)\)',
        source)
    invalid = []
    for declaration in declarations:
        for parameter in declaration[2].split(','):
            parameter = parameter.strip()
            if not parameter or parameter == '...':
                continue
            name = re.match(r'(?:const\s+)?&?(?:\w+:)?(\w+)\b', parameter)
            if not name:
                raise AssertionError('Unsupported parameter: '+parameter)
            if name[1] in PAWN_RESERVED_WORDS:
                invalid.append((declaration[1], name[1]))
    return invalid


class PawnParameterChecks(unittest.TestCase):
    def test_keywords_are_rejected_in_tagged_reference_and_array_parameters(self):
        for keyword in PAWN_RESERVED_WORDS:
            with self.subTest(keyword=keyword):
                self.assertEqual(reserved_parameters(
                    'stock probe(&Float:'+keyword+', const '+keyword+'[3]) {}'),
                    [('probe', keyword), ('probe', keyword)])
        self.assertEqual(reserved_parameters(
            '// stock example(forward) {}\n'
            'stock probe(const Float:feet[3], &Float:forward_speed, mode = 0)\n'
            '{ console_print(0, "stock example(state) {}"); }'), [])


def assignments(source, values):
    """Execute a flat Pawn assignment block, rejecting unsupported syntax."""
    source = source.replace('false', 'False').replace('true', 'True')
    source = re.sub(r'\b(\w+)\+\+', r'\1 += 1', source)
    source = '\n'.join(part.strip() for part in source.split(';') if part.strip())
    tree = ast.parse(source, mode='exec')
    allowed = (ast.Module, ast.Expr, ast.Assign, ast.AugAssign, ast.Name, ast.Load,
               ast.Store, ast.Subscript, ast.Constant, ast.Call, ast.BinOp,
               ast.Add, ast.Sub, ast.BitAnd, ast.BitOr, ast.LShift, ast.UnaryOp,
               ast.USub)
    if any(not isinstance(node, allowed) for node in ast.walk(tree)):
        raise AssertionError('Unsupported assignment syntax: '+source)
    exec(compile(tree, '<Pawn assignment contract>', 'exec'),
         {'__builtins__': {}}, values)


class MapperTeamContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = Path(__file__).resolve().parents[1]
        local = root/'LOCAL.md'
        match = re.search(r'^\| `ANPC_INCLUDE_DIR` \| `([^`]+)`',
                          local.read_text(encoding='utf-8-sig'), re.MULTILINE) if local.exists() else None
        if not match or not Path(match[1]).is_dir():
            raise unittest.SkipTest('External mapper includes unavailable')
        include = Path(match[1])
        cls.team = (include/'mapper_team.inc').read_text(encoding='utf-8-sig')
        cls.motion = (include/'mapper_motion.inc').read_text(encoding='utf-8-sig')
        cls.exploration = (include/'mapper_exploration.inc').read_text(encoding='utf-8-sig')
        cls.frontiers = (include/'mapper_frontiers.inc').read_text(encoding='utf-8-sig')
        cls.mapper = (root/'anpc_mapper.sma').read_text(encoding='utf-8-sig')
        cls.sources = {path.name: path.read_text(encoding='utf-8-sig')
                       for path in (root/'anpc_mapper.sma',
                                    include/'advanced_npc_mapper.inc',
                                    *sorted(include.glob('mapper_*.inc')))}
        cls.identity = body(cls.motion, 'scan_bot_valid').split('return ', 1)[1].strip()

    def test_mapper_function_parameters_do_not_use_reserved_words(self):
        for filename, source in self.sources.items():
            with self.subTest(filename=filename):
                self.assertEqual(reserved_parameters(source), [])

    def valid(self, index=0, connected=True, userid=101, private=2, fake=True):
        return predicate(self.identity, {
            'index': index, 'gBotCount': 3, 'MaxClients': 32,
            'gBot': [7, 12, 23], 'gBotUserid': [101, 102, 103],
            'is_user_connected': lambda slot: connected,
            'get_user_userid': lambda slot: userid,
            'pev_valid': lambda slot: private,
            'is_user_bot': lambda slot: fake,
        })

    def test_each_scout_has_an_independently_validated_identity(self):
        for index in range(3):
            self.assertTrue(self.valid(index=index, userid=101+index))

    def test_reused_slot_and_unregistered_or_human_clients_are_rejected(self):
        for case in ({'userid': 999}, {'connected': False},
                     {'private': 1}, {'fake': False}):
            with self.subTest(case=case):
                self.assertFalse(self.valid(**case))

    def test_out_of_range_scout_does_not_read_identity_arrays(self):
        for index in (-10, -1, 3, 32):
            self.assertFalse(self.valid(index=index))

    def test_collision_filter_only_excludes_distinct_owned_peers(self):
        guard = conditions(body(self.team, 'scan_physent_pre'))[0]
        for active in (False, True):
            for entity in (0, 7, 12, 19, 40):
                for client in (7, 12, 19):
                    values = {'gActive': active, 'entity': entity, 'client': client,
                              'scan_scout_index': lambda slot: {7: 0, 12: 1}.get(slot, -1)}
                    blocked = not predicate(guard, values)
                    self.assertEqual(blocked, active and entity != client
                                     and entity in (7, 12) and client in (7, 12))
        self.assertIn('SetHookChainReturn(ATYPE_BOOL, false)', body(self.team, 'scan_physent_pre'))

    def test_claim_rejects_a_peer_owner_and_invalid_nodes(self):
        guard = conditions(body(self.team, 'scan_claim_node'))[0]
        busy = body(self.team, 'scan_node_busy').split('return ', 1)[1].strip()
        for worker in range(3):
            for owner in range(4):
                for node in (-1, 0, 3):
                    values = {'node': node, 'gKnownCount': 3, 'gWorker': worker,
                              'gClaim': [owner]*3}
                    values['scan_node_busy'] = lambda n: predicate(busy, dict(values, node=n))
                    self.assertEqual(not predicate(guard, values),
                                     0 <= node < 3 and owner in (0, worker+1))

    def test_releasing_a_claim_never_erases_another_owner(self):
        function = body(self.team, 'scan_release_claim')
        guard = conditions(function)[0]
        block = re.search(r'\{([^{}]+)\}', function)[1]
        for owner in (0, 1, 2, 3):
            values = {'node': 1, 'index': 1, 'gClaim': [0, owner, 0], 'gClaimEpoch': 9}
            if predicate(guard, values):
                assignments(block, values)
            self.assertEqual(values['gClaim'][1], 0 if owner == 2 else owner)
            self.assertEqual(values['gClaimEpoch'], 10 if owner == 2 else 9)

    def test_pause_returns_the_scouts_own_seed_when_claimed_out_of_order(self):
        function = body(self.motion, 'scan_interrupt_trial')
        seed_expression = re.search(r'new seed = ([^\n]+)', function)[1]
        block = re.search(r'if \(seed >= 0\) \{([^{}]+)\}', function)[1]
        values = {'gWorker': 1, 'gSeedIndex': [8, 2, 5],
                  'gSeeds': [{'used': True} for _ in range(10)],
                  'SEED_USED': 'used', 'gSeedCursor': 9, 'min': min}
        values['ArraySetCell'] = lambda store, item, value, field: store[item].__setitem__(field, value)
        values['seed'] = eval(seed_expression, {'__builtins__': {}}, values)
        assignments(block, values)
        self.assertEqual(values['gSeedCursor'], 2)
        self.assertEqual([i for i, seed in enumerate(values['gSeeds']) if not seed['used']], [2])
        self.assertTrue(values['gSeeds'][8]['used'])
        self.assertTrue(values['gSeeds'][5]['used'])

    def test_interruptions_preserve_shared_proven_directions(self):
        function = body(self.motion, 'scan_interrupt_trial')
        self.assertNotRegex(function, r'\bgMask\s*\[')
        self.assertNotRegex(function, r'\bgParentClosed\s*\[')
        for name in ('scan_begin_frontier', 'scan_begin_return'):
            self.assertNotRegex(body(self.exploration, name), r'\bgMask\s*\[')

    def test_completed_trials_do_not_persist_derived_interior_masks(self):
        guard = conditions(body(self.team, 'scan_end_trial'))[0]
        for purpose in range(3):
            for interior in (0, 1 << 4):
                values = {'gWorker': 0, 'gPurpose': [purpose], 'SCAN_TRAVEL': 2,
                          'gSource': [0], 'gDirection': [4], 'gInteriorMask': [interior]}
                self.assertEqual(predicate(guard, values), purpose != 2 and interior == 0)

    def test_finished_peer_discoveries_cannot_starve_a_sensor_sweep(self):
        guard = conditions(body(self.exploration, 'scan_sense_step'))[0]
        values = {'gWorker': 0, 'gSenseNode': [4], 'gCurrent': [4],
                  'gSenseBlockEpoch': [3], 'gBlockGeometry': 3}
        self.assertFalse(predicate(guard, values))
        values['gBlockGeometry'] = 4
        self.assertTrue(predicate(guard, values))
        self.assertNotIn('gGraphEpoch', guard)

    def test_incremental_planning_can_finish_while_peers_add_nodes(self):
        guard = conditions(body(self.frontiers, 'scan_plan_step'))[0]
        self.assertFalse(predicate(guard, {'gWorker': 0, 'gPlanStart': [4], 'gCurrent': [4]}))
        self.assertNotIn('gGraphEpoch', guard)

    def test_side_steering_does_not_change_airborne_or_special_trials(self):
        guard = conditions(body(self.team, 'scan_avoid_peers'))[0]
        for motion in range(4):
            for airborne in (False, True):
                values = {'gBotCount': 4, 'gWorker': 0, 'gMotion': [motion],
                          'SCAN_WALK': 0, 'gAirborne': [airborne], 'forward_speed': 100.,
                          'gBot': [7], 'FL_ONGROUND': 512, 'var_flags': 0,
                          'get_entvar': lambda *args: 512}
                self.assertEqual(not predicate(guard, values), motion == 0 and not airborne)

    def test_team_completion_waits_for_survey_seeds_and_every_scout(self):
        guards = conditions(body(self.team, 'scan_team_complete'))
        for survey in (False, True):
            for pending_seed in (False, True):
                values = {'gSurveyDone': survey, 'gSeedCursor': 4,
                          'gSeedCount': 5 if pending_seed else 4}
                self.assertEqual(predicate(guards[0], values), not survey or pending_seed)
        for scout in range(4):
            values = {'gIdle': [True]*4, 'scout': scout}
            values['gIdle'][scout] = False
            self.assertTrue(predicate(guards[1], values))
        self.assertIn('scan_frontier_weight(node,false)', body(self.team, 'scan_team_complete'))

    def test_allocation_keeps_an_admin_slot_and_caps_the_team(self):
        expression = re.search(r'gBotCount = ([^\n]+)', body(self.mapper, 'scan_start'))[1]
        for slots in (2, 8, 16, 32):
            for players in range(slots-1):
                for requested in (1, 4, 8, 20):
                    count = eval(expression, {'__builtins__': {}}, {
                        'available': slots-1-players, 'gBotLimit': requested,
                        'SCAN_MAX_BOTS': 8, 'min': min,
                        'clamp': lambda n, low, high: max(low, min(high, n))})
                    self.assertGreaterEqual(count, 1)
                    self.assertLessEqual(count, 8)
                    self.assertLessEqual(players+count, slots-1)

    def test_a_deferred_pause_cannot_suspend_an_active_checkpoint(self):
        guard = conditions(body(self.team, 'scan_pause_team'))[0]
        for active in (False, True):
            for stage in (1, 2, 6, 7):
                values = {'gActive': active, 'gSessionStage': stage, 'ANPC_SCAN_SAVE': 7}
                self.assertEqual(predicate(guard, values), not active or stage == 7)


if __name__ == '__main__':
    unittest.main()
