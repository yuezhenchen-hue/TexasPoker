from __future__ import annotations

from enum import Enum

from .card import Deck
from .hand_evaluator import HandEvaluator, HandRank
from .player import Player, AIPlayer, Action


class GamePhase(Enum):
    WAITING = "等待开始"
    PRE_FLOP = "翻牌前"
    FLOP = "翻牌"
    TURN = "转牌"
    RIVER = "河牌"
    SHOWDOWN = "摊牌"
    HAND_OVER = "本局结束"


class Game:
    SMALL_BLIND = 10
    BIG_BLIND = 20

    def __init__(self, player_names: list[str] | None = None):
        self.human = Player("你", chips=1000, is_human=True)
        ai_names = player_names or ["Alice", "Bob", "Charlie", "Diana"]
        self.ai_players = [AIPlayer(name, chips=1000) for name in ai_names]
        self.players: list[Player] = [self.human] + self.ai_players
        self.deck = Deck()
        self.community_cards = []
        self.pot = 0
        self.side_pots: list[tuple[int, list[Player]]] = []
        self.phase = GamePhase.WAITING
        self.dealer_index = 0
        self.current_player_index = 0
        self.current_bet = 0
        self.min_raise = self.BIG_BLIND
        self.last_raiser_index = -1
        self.message = "按 [开始] 开始新一局"
        self.hand_results: list[dict] = []
        self.round_complete = False
        self.waiting_for_human = False
        self.hand_number = 0

    @property
    def active_players(self) -> list[Player]:
        return [p for p in self.players if not p.is_folded and p.chips + p.total_bet_this_round > 0]

    @property
    def players_in_hand(self) -> list[Player]:
        return [p for p in self.players if not p.is_folded]

    @property
    def current_player(self) -> Player | None:
        if 0 <= self.current_player_index < len(self.players):
            return self.players[self.current_player_index]
        return None

    def remove_broke_players(self):
        broke = [p for p in self.ai_players if p.chips <= 0]
        for p in broke:
            self.players.remove(p)
            self.ai_players.remove(p)
        if self.dealer_index >= len(self.players):
            self.dealer_index = 0

    def start_new_hand(self):
        self.remove_broke_players()
        if len(self.players) < 2:
            self.message = "游戏结束！"
            self.phase = GamePhase.HAND_OVER
            return
        if self.human.chips <= 0:
            self.message = "你已经没有筹码了！游戏结束！"
            self.phase = GamePhase.HAND_OVER
            return

        self.hand_number += 1
        self.deck.reset()
        self.community_cards = []
        self.pot = 0
        self.side_pots = []
        self.current_bet = 0
        self.min_raise = self.BIG_BLIND
        self.hand_results = []
        self.round_complete = False

        for p in self.players:
            p.reset_for_new_hand()

        self.dealer_index = self.dealer_index % len(self.players)
        self._assign_positions()
        self._post_blinds()
        self._deal_hole_cards()

        self.phase = GamePhase.PRE_FLOP
        self._set_first_player_preflop()
        self.message = f"第 {self.hand_number} 局 — 翻牌前"
        self._check_if_waiting_for_human()

    def _assign_positions(self):
        n = len(self.players)
        self.players[self.dealer_index].is_dealer = True
        sb_idx = (self.dealer_index + 1) % n
        bb_idx = (self.dealer_index + 2) % n
        self.players[sb_idx].is_small_blind = True
        self.players[bb_idx].is_big_blind = True

    def _post_blinds(self):
        n = len(self.players)
        sb_idx = (self.dealer_index + 1) % n
        bb_idx = (self.dealer_index + 2) % n
        sb_player = self.players[sb_idx]
        bb_player = self.players[bb_idx]
        sb_actual = sb_player.bet(self.SMALL_BLIND)
        bb_actual = bb_player.bet(self.BIG_BLIND)
        self.pot += sb_actual + bb_actual
        self.current_bet = self.BIG_BLIND

    def _deal_hole_cards(self):
        for p in self.players:
            p.hole_cards = self.deck.deal(2)

    def _set_first_player_preflop(self):
        n = len(self.players)
        self.current_player_index = (self.dealer_index + 3) % n
        self.last_raiser_index = (self.dealer_index + 2) % n
        self._skip_inactive()

    def _set_first_player_postflop(self):
        n = len(self.players)
        self.current_player_index = (self.dealer_index + 1) % n
        self.last_raiser_index = -1
        self._skip_inactive()

    def _skip_inactive(self):
        n = len(self.players)
        attempts = 0
        while attempts < n:
            p = self.players[self.current_player_index]
            if p.is_active:
                return
            self.current_player_index = (self.current_player_index + 1) % n
            attempts += 1

    def _check_if_waiting_for_human(self):
        p = self.current_player
        if p and p.is_human and p.is_active:
            self.waiting_for_human = True
        else:
            self.waiting_for_human = False

    def process_ai_turn(self) -> tuple[str, Action] | None:
        player = self.current_player
        if player is None or player.is_human or not player.is_active:
            return None
        if not isinstance(player, AIPlayer):
            return None

        action, amount = player.decide_action(
            self.community_cards, self.pot, self.current_bet, self.min_raise
        )
        return self._execute_action(player, action, amount)

    def process_human_action(self, action: Action, amount: int = 0) -> tuple[str, Action]:
        player = self.human
        self.waiting_for_human = False
        return self._execute_action(player, action, amount)

    def _execute_action(self, player: Player, action: Action, amount: int) -> tuple[str, Action]:
        if action == Action.FOLD:
            player.is_folded = True
            msg = f"{player.name} 弃牌"

        elif action == Action.CHECK:
            msg = f"{player.name} 过牌"

        elif action == Action.CALL:
            to_call = self.current_bet - player.current_bet
            actual = player.bet(to_call)
            self.pot += actual
            msg = f"{player.name} 跟注 {actual}"

        elif action == Action.RAISE:
            to_call = self.current_bet - player.current_bet
            total_bet = to_call + amount
            actual = player.bet(total_bet)
            self.pot += actual
            self.current_bet = player.current_bet
            self.min_raise = max(self.min_raise, amount)
            self.last_raiser_index = self.current_player_index
            msg = f"{player.name} 加注到 {player.current_bet}"

        elif action == Action.ALL_IN:
            actual = player.bet(player.chips)
            self.pot += actual
            if player.current_bet > self.current_bet:
                self.current_bet = player.current_bet
                self.last_raiser_index = self.current_player_index
            msg = f"{player.name} 全下 {actual}"
        else:
            msg = ""

        self.message = msg
        self._advance_to_next_player()
        return msg, action

    def _advance_to_next_player(self):
        active_non_allin = [p for p in self.players if p.is_active]

        if len(self.players_in_hand) <= 1:
            self._end_hand_early()
            return

        if len(active_non_allin) <= 1 and all(
            p.current_bet == self.current_bet or p.is_all_in or p.is_folded
            for p in self.players
        ):
            self._fast_forward_to_showdown()
            return

        n = len(self.players)
        next_idx = (self.current_player_index + 1) % n

        attempts = 0
        while attempts < n:
            if next_idx == self.last_raiser_index:
                self._advance_phase()
                return
            p = self.players[next_idx]
            if p.is_active:
                self.current_player_index = next_idx
                self._check_if_waiting_for_human()
                return
            next_idx = (next_idx + 1) % n
            attempts += 1

        self._advance_phase()

    def _advance_phase(self):
        for p in self.players:
            p.reset_current_bet()
        self.current_bet = 0
        self.min_raise = self.BIG_BLIND

        if self.phase == GamePhase.PRE_FLOP:
            self.phase = GamePhase.FLOP
            self.deck.deal_one()  # burn
            self.community_cards.extend(self.deck.deal(3))
            self.message = "翻牌"
        elif self.phase == GamePhase.FLOP:
            self.phase = GamePhase.TURN
            self.deck.deal_one()  # burn
            self.community_cards.extend(self.deck.deal(1))
            self.message = "转牌"
        elif self.phase == GamePhase.TURN:
            self.phase = GamePhase.RIVER
            self.deck.deal_one()  # burn
            self.community_cards.extend(self.deck.deal(1))
            self.message = "河牌"
        elif self.phase == GamePhase.RIVER:
            self._showdown()
            return

        self._set_first_player_postflop()
        self._check_if_waiting_for_human()

        if len([p for p in self.players if p.is_active]) <= 1:
            all_matched = all(
                p.current_bet == self.current_bet or p.is_all_in or p.is_folded
                for p in self.players
            )
            if all_matched:
                self._fast_forward_to_showdown()

    def _fast_forward_to_showdown(self):
        while self.phase not in (GamePhase.SHOWDOWN, GamePhase.HAND_OVER):
            for p in self.players:
                p.reset_current_bet()
            self.current_bet = 0

            if self.phase == GamePhase.PRE_FLOP:
                self.phase = GamePhase.FLOP
                self.deck.deal_one()
                self.community_cards.extend(self.deck.deal(3))
            elif self.phase == GamePhase.FLOP:
                self.phase = GamePhase.TURN
                self.deck.deal_one()
                self.community_cards.extend(self.deck.deal(1))
            elif self.phase == GamePhase.TURN:
                self.phase = GamePhase.RIVER
                self.deck.deal_one()
                self.community_cards.extend(self.deck.deal(1))
            elif self.phase == GamePhase.RIVER:
                self._showdown()
                return

        self._showdown()

    def _end_hand_early(self):
        winner = self.players_in_hand[0]
        winner.chips += self.pot
        self.hand_results = [{"player": winner, "winnings": self.pot, "hand_desc": "其他人弃牌"}]
        self.message = f"{winner.name} 赢得 {self.pot} 筹码（其他人弃牌）"
        self.pot = 0
        self.phase = GamePhase.HAND_OVER
        self.dealer_index = (self.dealer_index + 1) % len(self.players)
        self.waiting_for_human = False

    def _showdown(self):
        self.phase = GamePhase.SHOWDOWN
        contenders = self.players_in_hand
        evaluations = []

        for p in contenders:
            rank, tiebreakers, desc = HandEvaluator.evaluate(p.hole_cards, self.community_cards)
            evaluations.append((p, rank, tiebreakers, desc))

        evaluations.sort(key=lambda x: (x[1], x[2]), reverse=True)

        self.hand_results = []
        remaining_pot = self.pot
        winners = []

        best_rank = evaluations[0][1]
        best_tb = evaluations[0][2]
        for p, rank, tb, desc in evaluations:
            if rank == best_rank and tb == best_tb:
                winners.append((p, desc))

        share = remaining_pot // len(winners)
        for p, desc in winners:
            p.chips += share
            self.hand_results.append({"player": p, "winnings": share, "hand_desc": desc})

        if len(winners) == 1:
            w, desc = winners[0]
            self.message = f"{w.name} 赢得 {remaining_pot} 筹码 — {desc}"
        else:
            names = "、".join(w.name for w, _ in winners)
            self.message = f"{names} 平分 {remaining_pot} 筹码"

        self.pot = 0
        self.phase = GamePhase.HAND_OVER
        self.dealer_index = (self.dealer_index + 1) % len(self.players)
        self.waiting_for_human = False

    def get_human_options(self) -> list[tuple[Action, int]]:
        options = []
        to_call = self.current_bet - self.human.current_bet

        options.append((Action.FOLD, 0))

        if to_call == 0:
            options.append((Action.CHECK, 0))
        else:
            if to_call <= self.human.chips:
                options.append((Action.CALL, to_call))

        if self.human.chips > to_call:
            raise_amount = self.min_raise
            if to_call + raise_amount <= self.human.chips:
                options.append((Action.RAISE, raise_amount))

        options.append((Action.ALL_IN, self.human.chips))

        return options
