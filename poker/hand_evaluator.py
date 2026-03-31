from __future__ import annotations

from itertools import combinations
from collections import Counter

from .card import Card


class HandRank:
    HIGH_CARD = 0
    ONE_PAIR = 1
    TWO_PAIR = 2
    THREE_OF_A_KIND = 3
    STRAIGHT = 4
    FLUSH = 5
    FULL_HOUSE = 6
    FOUR_OF_A_KIND = 7
    STRAIGHT_FLUSH = 8
    ROYAL_FLUSH = 9

    NAMES = {
        0: "高牌",
        1: "一对",
        2: "两对",
        3: "三条",
        4: "顺子",
        5: "同花",
        6: "葫芦",
        7: "四条",
        8: "同花顺",
        9: "皇家同花顺",
    }


class HandEvaluator:
    """评估德州扑克手牌，从7张牌中选出最优5张组合。"""

    @staticmethod
    def evaluate(hole_cards: list[Card], community_cards: list[Card]) -> tuple[int, list[int], str]:
        """
        返回 (hand_rank, tiebreakers, description)
        hand_rank: HandRank 常量
        tiebreakers: 用于比较同级别手牌的列表
        description: 手牌描述字符串
        """
        all_cards = hole_cards + community_cards
        if len(all_cards) < 5:
            return HandRank.HIGH_CARD, [c.rank for c in sorted(all_cards, reverse=True)], "高牌"

        best_rank = -1
        best_tiebreakers = []
        best_desc = ""

        for combo in combinations(all_cards, 5):
            cards = list(combo)
            rank, tiebreakers, desc = HandEvaluator._evaluate_five(cards)
            if (rank, tiebreakers) > (best_rank, best_tiebreakers):
                best_rank = rank
                best_tiebreakers = tiebreakers
                best_desc = desc

        return best_rank, best_tiebreakers, best_desc

    @staticmethod
    def _evaluate_five(cards: list[Card]) -> tuple[int, list[int], str]:
        ranks = sorted([c.rank for c in cards], reverse=True)
        suits = [c.suit for c in cards]
        rank_counts = Counter(ranks)
        is_flush = len(set(suits)) == 1
        is_straight, high = HandEvaluator._check_straight(ranks)

        counts_sorted = sorted(rank_counts.items(), key=lambda x: (x[1], x[0]), reverse=True)
        count_values = [c for _, c in counts_sorted]

        if is_straight and is_flush:
            if high == 14:
                return HandRank.ROYAL_FLUSH, [high], "皇家同花顺"
            return HandRank.STRAIGHT_FLUSH, [high], "同花顺"

        if count_values[0] == 4:
            quad_rank = counts_sorted[0][0]
            kicker = counts_sorted[1][0]
            return HandRank.FOUR_OF_A_KIND, [quad_rank, kicker], "四条"

        if count_values[0] == 3 and count_values[1] == 2:
            trip_rank = counts_sorted[0][0]
            pair_rank = counts_sorted[1][0]
            return HandRank.FULL_HOUSE, [trip_rank, pair_rank], "葫芦"

        if is_flush:
            return HandRank.FLUSH, ranks, "同花"

        if is_straight:
            return HandRank.STRAIGHT, [high], "顺子"

        if count_values[0] == 3:
            trip_rank = counts_sorted[0][0]
            kickers = sorted([r for r, c in counts_sorted if c == 1], reverse=True)
            return HandRank.THREE_OF_A_KIND, [trip_rank] + kickers, "三条"

        if count_values[0] == 2 and count_values[1] == 2:
            pairs = sorted([r for r, c in counts_sorted if c == 2], reverse=True)
            kicker = [r for r, c in counts_sorted if c == 1][0]
            return HandRank.TWO_PAIR, pairs + [kicker], "两对"

        if count_values[0] == 2:
            pair_rank = counts_sorted[0][0]
            kickers = sorted([r for r, c in counts_sorted if c == 1], reverse=True)
            return HandRank.ONE_PAIR, [pair_rank] + kickers, "一对"

        return HandRank.HIGH_CARD, ranks, "高牌"

    @staticmethod
    def _check_straight(ranks: list[int]) -> tuple[bool, int]:
        unique = sorted(set(ranks), reverse=True)
        if len(unique) < 5:
            return False, 0

        if unique == list(range(unique[0], unique[0] - 5, -1)):
            return True, unique[0]

        # A-2-3-4-5 (轮子)
        if set(unique) == {14, 2, 3, 4, 5}:
            return True, 5

        return False, 0

    @staticmethod
    def compare_hands(
        hand1: tuple[int, list[int]],
        hand2: tuple[int, list[int]],
    ) -> int:
        """返回 1 表示 hand1 赢, -1 表示 hand2 赢, 0 表示平局。"""
        if hand1[0] != hand2[0]:
            return 1 if hand1[0] > hand2[0] else -1
        if hand1[1] != hand2[1]:
            return 1 if hand1[1] > hand2[1] else -1
        return 0
