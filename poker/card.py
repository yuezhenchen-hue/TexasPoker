from __future__ import annotations

import random
from enum import IntEnum


class Suit(IntEnum):
    CLUBS = 0
    DIAMONDS = 1
    HEARTS = 2
    SPADES = 3


SUIT_SYMBOLS = {
    Suit.CLUBS: "♣",
    Suit.DIAMONDS: "♦",
    Suit.HEARTS: "♥",
    Suit.SPADES: "♠",
}

SUIT_COLORS = {
    Suit.CLUBS: (30, 30, 30),
    Suit.DIAMONDS: (200, 30, 30),
    Suit.HEARTS: (200, 30, 30),
    Suit.SPADES: (30, 30, 30),
}

RANK_NAMES = {
    2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8",
    9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A",
}


class Card:
    __slots__ = ("rank", "suit")

    def __init__(self, rank: int, suit: Suit):
        self.rank = rank
        self.suit = suit

    @property
    def symbol(self) -> str:
        return SUIT_SYMBOLS[self.suit]

    @property
    def rank_str(self) -> str:
        return RANK_NAMES[self.rank]

    @property
    def color(self) -> tuple:
        return SUIT_COLORS[self.suit]

    @property
    def is_red(self) -> bool:
        return self.suit in (Suit.HEARTS, Suit.DIAMONDS)

    def __repr__(self) -> str:
        return f"{self.rank_str}{self.symbol}"

    def __eq__(self, other) -> bool:
        if not isinstance(other, Card):
            return NotImplemented
        return self.rank == other.rank and self.suit == other.suit

    def __hash__(self) -> int:
        return hash((self.rank, self.suit))

    def __lt__(self, other) -> bool:
        if not isinstance(other, Card):
            return NotImplemented
        return self.rank < other.rank


class Deck:
    def __init__(self):
        self.cards: list[Card] = []
        self.reset()

    def reset(self):
        self.cards = [
            Card(rank, suit)
            for suit in Suit
            for rank in range(2, 15)
        ]
        self.shuffle()

    def shuffle(self):
        random.shuffle(self.cards)

    def deal(self, count: int = 1) -> list[Card]:
        dealt = self.cards[:count]
        self.cards = self.cards[count:]
        return dealt

    def deal_one(self) -> Card:
        return self.cards.pop(0)

    def __len__(self) -> int:
        return len(self.cards)
