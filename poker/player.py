from __future__ import annotations

import random
from enum import Enum

from .card import Card
from .hand_evaluator import HandEvaluator, HandRank


class Action(Enum):
    FOLD = "弃牌"
    CHECK = "过牌"
    CALL = "跟注"
    RAISE = "加注"
    ALL_IN = "全下"


class Player:
    def __init__(self, name: str, chips: int = 1000, is_human: bool = False):
        self.name = name
        self.chips = chips
        self.is_human = is_human
        self.hole_cards: list[Card] = []
        self.current_bet: int = 0
        self.total_bet_this_round: int = 0
        self.is_folded: bool = False
        self.is_all_in: bool = False
        self.is_dealer: bool = False
        self.is_small_blind: bool = False
        self.is_big_blind: bool = False

    def reset_for_new_hand(self):
        self.hole_cards = []
        self.current_bet = 0
        self.total_bet_this_round = 0
        self.is_folded = False
        self.is_all_in = False
        self.is_dealer = False
        self.is_small_blind = False
        self.is_big_blind = False

    def bet(self, amount: int) -> int:
        actual = min(amount, self.chips)
        self.chips -= actual
        self.current_bet += actual
        self.total_bet_this_round += actual
        if self.chips == 0:
            self.is_all_in = True
        return actual

    def reset_current_bet(self):
        self.current_bet = 0

    @property
    def is_active(self) -> bool:
        return not self.is_folded and not self.is_all_in and self.chips > 0

    def __repr__(self) -> str:
        return f"Player({self.name}, chips={self.chips})"


class AIPlayer(Player):
    """带有简单策略的 AI 玩家。"""

    STYLE_TIGHT = "tight"
    STYLE_LOOSE = "loose"
    STYLE_AGGRESSIVE = "aggressive"

    def __init__(self, name: str, chips: int = 1000, style: str | None = None):
        super().__init__(name, chips, is_human=False)
        self.style = style or random.choice([
            self.STYLE_TIGHT, self.STYLE_LOOSE, self.STYLE_AGGRESSIVE
        ])

    def decide_action(
        self,
        community_cards: list[Card],
        pot: int,
        current_bet: int,
        min_raise: int,
    ) -> tuple[Action, int]:
        to_call = current_bet - self.current_bet
        hand_strength = self._evaluate_strength(community_cards)

        if to_call > self.chips:
            if hand_strength > 0.5:
                return Action.ALL_IN, self.chips
            return Action.FOLD, 0

        if self.style == self.STYLE_TIGHT:
            return self._tight_strategy(hand_strength, to_call, min_raise, pot)
        elif self.style == self.STYLE_AGGRESSIVE:
            return self._aggressive_strategy(hand_strength, to_call, min_raise, pot)
        else:
            return self._loose_strategy(hand_strength, to_call, min_raise, pot)

    def _evaluate_strength(self, community_cards: list[Card]) -> float:
        if not community_cards:
            return self._preflop_strength()

        rank, tiebreakers, _ = HandEvaluator.evaluate(self.hole_cards, community_cards)
        base = rank / HandRank.ROYAL_FLUSH
        kicker_bonus = 0
        if tiebreakers:
            kicker_bonus = tiebreakers[0] / 14.0 * 0.1
        return min(1.0, base + kicker_bonus + random.uniform(-0.1, 0.1))

    def _preflop_strength(self) -> float:
        if len(self.hole_cards) < 2:
            return 0.3
        c1, c2 = self.hole_cards
        strength = 0.2

        if c1.rank == c2.rank:
            strength += 0.3 + (c1.rank / 14.0) * 0.3

        high = max(c1.rank, c2.rank)
        strength += (high / 14.0) * 0.15

        if c1.suit == c2.suit:
            strength += 0.06

        gap = abs(c1.rank - c2.rank)
        if gap <= 2:
            strength += 0.05

        strength += random.uniform(-0.08, 0.08)
        return max(0.0, min(1.0, strength))

    def _tight_strategy(self, strength, to_call, min_raise, pot):
        if strength > 0.7:
            raise_amt = min(min_raise * 2, self.chips)
            return Action.RAISE, raise_amt
        if strength > 0.4:
            if to_call == 0:
                return Action.CHECK, 0
            if to_call <= pot * 0.3:
                return Action.CALL, to_call
            return Action.FOLD, 0
        if to_call == 0:
            return Action.CHECK, 0
        return Action.FOLD, 0

    def _aggressive_strategy(self, strength, to_call, min_raise, pot):
        if strength > 0.5:
            raise_amt = min(min_raise * 3, self.chips)
            return Action.RAISE, raise_amt
        if strength > 0.25:
            if random.random() < 0.4:
                raise_amt = min(min_raise * 2, self.chips)
                return Action.RAISE, raise_amt
            if to_call == 0:
                return Action.CHECK, 0
            return Action.CALL, to_call
        if to_call == 0:
            if random.random() < 0.2:
                return Action.RAISE, min(min_raise, self.chips)
            return Action.CHECK, 0
        if to_call <= pot * 0.2:
            return Action.CALL, to_call
        return Action.FOLD, 0

    def _loose_strategy(self, strength, to_call, min_raise, pot):
        if strength > 0.6:
            raise_amt = min(min_raise * 2, self.chips)
            return Action.RAISE, raise_amt
        if strength > 0.3:
            if to_call == 0:
                if random.random() < 0.3:
                    return Action.RAISE, min(min_raise, self.chips)
                return Action.CHECK, 0
            return Action.CALL, to_call
        if to_call == 0:
            return Action.CHECK, 0
        if to_call <= pot * 0.4:
            if random.random() < 0.4:
                return Action.CALL, to_call
        return Action.FOLD, 0
