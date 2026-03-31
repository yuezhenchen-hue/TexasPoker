from __future__ import annotations

import math
import pygame

from poker.card import Card, Suit, SUIT_SYMBOLS, SUIT_COLORS, RANK_NAMES
from poker.player import Player, Action
from poker.game import Game, GamePhase
from poker.hand_evaluator import HandRank


WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 800
TABLE_CENTER = (WINDOW_WIDTH // 2, WINDOW_HEIGHT // 2 - 20)
TABLE_RX = 420
TABLE_RY = 220

CARD_WIDTH = 60
CARD_HEIGHT = 84
CARD_RADIUS = 6

COLORS = {
    "bg": (20, 20, 35),
    "table_felt": (30, 100, 50),
    "table_border": (80, 50, 20),
    "table_rim": (120, 75, 30),
    "card_white": (250, 250, 250),
    "card_back": (35, 55, 120),
    "card_back_pattern": (50, 75, 150),
    "gold": (255, 200, 50),
    "text_white": (240, 240, 240),
    "text_dim": (160, 160, 160),
    "chip_green": (60, 160, 60),
    "pot_bg": (0, 0, 0, 120),
    "panel_bg": (30, 30, 50, 200),
    "red": (220, 50, 50),
    "dealer_yellow": (255, 220, 50),
}

PLAYER_POSITIONS_5 = [
    (WINDOW_WIDTH // 2, WINDOW_HEIGHT - 95),
    (120, WINDOW_HEIGHT // 2 + 60),
    (220, 120),
    (WINDOW_WIDTH - 220, 120),
    (WINDOW_WIDTH - 120, WINDOW_HEIGHT // 2 + 60),
]

PLAYER_POSITIONS_4 = [
    (WINDOW_WIDTH // 2, WINDOW_HEIGHT - 95),
    (120, WINDOW_HEIGHT // 2 + 20),
    (WINDOW_WIDTH // 2, 100),
    (WINDOW_WIDTH - 120, WINDOW_HEIGHT // 2 + 20),
]

PLAYER_POSITIONS_3 = [
    (WINDOW_WIDTH // 2, WINDOW_HEIGHT - 95),
    (180, 180),
    (WINDOW_WIDTH - 180, 180),
]

PLAYER_POSITIONS_2 = [
    (WINDOW_WIDTH // 2, WINDOW_HEIGHT - 95),
    (WINDOW_WIDTH // 2, 120),
]


def get_positions(count):
    if count <= 2:
        return PLAYER_POSITIONS_2[:count]
    if count == 3:
        return PLAYER_POSITIONS_3
    if count == 4:
        return PLAYER_POSITIONS_4
    return PLAYER_POSITIONS_5[:count]


class Renderer:
    def __init__(self, screen: pygame.Surface):
        self.screen = screen
        try:
            self.font_large = pygame.font.SysFont("PingFang SC", 28, bold=True)
            self.font_medium = pygame.font.SysFont("PingFang SC", 20)
            self.font_small = pygame.font.SysFont("PingFang SC", 16)
            self.font_card = pygame.font.SysFont("Arial", 18, bold=True)
            self.font_card_symbol = pygame.font.SysFont("Arial", 26)
            self.font_card_center = pygame.font.SysFont("Arial", 32, bold=True)
            self.font_title = pygame.font.SysFont("PingFang SC", 36, bold=True)
        except Exception:
            self.font_large = pygame.font.Font(None, 32)
            self.font_medium = pygame.font.Font(None, 24)
            self.font_small = pygame.font.Font(None, 20)
            self.font_card = pygame.font.Font(None, 22)
            self.font_card_symbol = pygame.font.Font(None, 30)
            self.font_card_center = pygame.font.Font(None, 36)
            self.font_title = pygame.font.Font(None, 42)

    def draw_background(self):
        self.screen.fill(COLORS["bg"])

    def draw_table(self):
        cx, cy = TABLE_CENTER

        for i in range(5, 0, -1):
            alpha = 15 + i * 8
            s = pygame.Surface((WINDOW_WIDTH, WINDOW_HEIGHT), pygame.SRCALPHA)
            pygame.draw.ellipse(
                s,
                (*COLORS["table_border"], alpha),
                (cx - TABLE_RX - 15 - i * 3, cy - TABLE_RY - 15 - i * 3,
                 (TABLE_RX + 15 + i * 3) * 2, (TABLE_RY + 15 + i * 3) * 2),
            )
            self.screen.blit(s, (0, 0))

        pygame.draw.ellipse(
            self.screen,
            COLORS["table_rim"],
            (cx - TABLE_RX - 15, cy - TABLE_RY - 15,
             (TABLE_RX + 15) * 2, (TABLE_RY + 15) * 2),
        )
        pygame.draw.ellipse(
            self.screen,
            COLORS["table_border"],
            (cx - TABLE_RX - 8, cy - TABLE_RY - 8,
             (TABLE_RX + 8) * 2, (TABLE_RY + 8) * 2),
        )
        pygame.draw.ellipse(
            self.screen,
            COLORS["table_felt"],
            (cx - TABLE_RX, cy - TABLE_RY, TABLE_RX * 2, TABLE_RY * 2),
        )

        s = pygame.Surface((WINDOW_WIDTH, WINDOW_HEIGHT), pygame.SRCALPHA)
        pygame.draw.ellipse(
            s,
            (255, 255, 255, 12),
            (cx - TABLE_RX + 30, cy - TABLE_RY + 15,
             (TABLE_RX - 30) * 2, int(TABLE_RY * 0.7) * 2),
        )
        self.screen.blit(s, (0, 0))

    def draw_card(self, card: Card, x: int, y: int, face_up: bool = True, highlight: bool = False):
        rect = pygame.Rect(x, y, CARD_WIDTH, CARD_HEIGHT)

        if highlight:
            glow = pygame.Surface((CARD_WIDTH + 8, CARD_HEIGHT + 8), pygame.SRCALPHA)
            pygame.draw.rect(glow, (255, 215, 0, 100), glow.get_rect(), border_radius=CARD_RADIUS + 2)
            self.screen.blit(glow, (x - 4, y - 4))

        if not face_up:
            pygame.draw.rect(self.screen, COLORS["card_back"], rect, border_radius=CARD_RADIUS)
            inner = pygame.Rect(x + 4, y + 4, CARD_WIDTH - 8, CARD_HEIGHT - 8)
            pygame.draw.rect(self.screen, COLORS["card_back_pattern"], inner, border_radius=CARD_RADIUS - 2)
            pygame.draw.rect(self.screen, (80, 100, 180), inner, width=1, border_radius=CARD_RADIUS - 2)

            pattern_surface = pygame.Surface((CARD_WIDTH - 8, CARD_HEIGHT - 8), pygame.SRCALPHA)
            for i in range(3, CARD_WIDTH - 8, 8):
                pygame.draw.line(pattern_surface, (60, 85, 165, 80), (i, 0), (i, CARD_HEIGHT - 8))
            for j in range(3, CARD_HEIGHT - 8, 8):
                pygame.draw.line(pattern_surface, (60, 85, 165, 80), (0, j), (CARD_WIDTH - 8, j))
            self.screen.blit(pattern_surface, (x + 4, y + 4))
            return

        pygame.draw.rect(self.screen, COLORS["card_white"], rect, border_radius=CARD_RADIUS)
        pygame.draw.rect(self.screen, (180, 180, 180), rect, width=1, border_radius=CARD_RADIUS)

        color = SUIT_COLORS[card.suit]

        rank_text = self.font_card.render(card.rank_str, True, color)
        self.screen.blit(rank_text, (x + 5, y + 4))

        suit_text = self.font_card.render(card.symbol, True, color)
        self.screen.blit(suit_text, (x + 5, y + 22))

        center_text = self.font_card_center.render(card.symbol, True, color)
        center_rect = center_text.get_rect(center=(x + CARD_WIDTH // 2, y + CARD_HEIGHT // 2 + 4))
        self.screen.blit(center_text, center_rect)

    def draw_community_cards(self, cards: list[Card]):
        if not cards:
            return
        total_width = len(cards) * (CARD_WIDTH + 8) - 8
        start_x = TABLE_CENTER[0] - total_width // 2
        y = TABLE_CENTER[1] - CARD_HEIGHT // 2

        for i, card in enumerate(cards):
            self.draw_card(card, start_x + i * (CARD_WIDTH + 8), y)

    def draw_pot(self, pot: int, phase: GamePhase):
        if pot <= 0:
            return
        cx, cy = TABLE_CENTER
        pot_y = cy - CARD_HEIGHT // 2 - 45

        s = pygame.Surface((160, 32), pygame.SRCALPHA)
        pygame.draw.rect(s, (0, 0, 0, 140), s.get_rect(), border_radius=12)
        self.screen.blit(s, (cx - 80, pot_y))

        text = self.font_medium.render(f"底池: {pot}", True, COLORS["gold"])
        text_rect = text.get_rect(center=(cx, pot_y + 16))
        self.screen.blit(text, text_rect)

    def draw_player(self, player: Player, pos: tuple[int, int], is_current: bool, show_cards: bool, game_phase: GamePhase):
        px, py = pos
        is_bottom = py > WINDOW_HEIGHT // 2

        panel_w, panel_h = 140, 60
        panel_x = px - panel_w // 2
        panel_y = py - panel_h // 2

        s = pygame.Surface((panel_w, panel_h), pygame.SRCALPHA)
        if player.is_folded:
            bg_color = (60, 60, 60, 160)
        elif is_current:
            bg_color = (60, 130, 60, 200)
        else:
            bg_color = (40, 40, 65, 200)
        pygame.draw.rect(s, bg_color, s.get_rect(), border_radius=10)
        if is_current:
            pygame.draw.rect(s, (100, 220, 100, 200), s.get_rect(), width=2, border_radius=10)
        self.screen.blit(s, (panel_x, panel_y))

        name_text = self.font_small.render(player.name, True, COLORS["text_white"])
        name_rect = name_text.get_rect(center=(px, panel_y + 18))
        self.screen.blit(name_text, name_rect)

        chip_text = self.font_small.render(f"${player.chips}", True, COLORS["gold"])
        chip_rect = chip_text.get_rect(center=(px, panel_y + 40))
        self.screen.blit(chip_text, chip_rect)

        if player.is_dealer:
            d_radius = 12
            dx = panel_x + panel_w + 8
            dy = panel_y + panel_h // 2
            pygame.draw.circle(self.screen, COLORS["dealer_yellow"], (dx, dy), d_radius)
            pygame.draw.circle(self.screen, (180, 150, 20), (dx, dy), d_radius, 2)
            d_text = self.font_small.render("D", True, (30, 30, 30))
            d_rect = d_text.get_rect(center=(dx, dy))
            self.screen.blit(d_text, d_rect)

        if player.current_bet > 0:
            bet_text = self.font_small.render(f"下注: {player.current_bet}", True, (200, 200, 255))
            if is_bottom:
                bet_pos = (px, panel_y - 18)
            else:
                bet_pos = (px, panel_y + panel_h + 5)
            bet_rect = bet_text.get_rect(center=bet_pos)
            self.screen.blit(bet_text, bet_rect)

        if player.is_folded:
            fold_text = self.font_small.render("已弃牌", True, (180, 80, 80))
            fold_rect = fold_text.get_rect(center=(px, panel_y + panel_h + 20))
            self.screen.blit(fold_text, fold_rect)
            return

        if player.is_all_in:
            allin_text = self.font_small.render("ALL IN", True, (255, 80, 80))
            allin_rect = allin_text.get_rect(center=(px, panel_y + panel_h + 20))
            self.screen.blit(allin_text, allin_rect)

        if player.hole_cards:
            card_y = panel_y + panel_h + 8 if not is_bottom else panel_y - CARD_HEIGHT - 8
            total_w = 2 * CARD_WIDTH + 6
            card_x = px - total_w // 2

            face_up = show_cards or player.is_human
            if game_phase == GamePhase.SHOWDOWN or game_phase == GamePhase.HAND_OVER:
                face_up = not player.is_folded

            for i, card in enumerate(player.hole_cards):
                self.draw_card(card, card_x + i * (CARD_WIDTH + 6), card_y, face_up=face_up)

    def draw_players(self, game: Game):
        positions = get_positions(len(game.players))
        for i, player in enumerate(game.players):
            if i < len(positions):
                is_current = (i == game.current_player_index and
                              game.phase not in (GamePhase.WAITING, GamePhase.HAND_OVER, GamePhase.SHOWDOWN))
                show_cards = game.phase in (GamePhase.SHOWDOWN, GamePhase.HAND_OVER)
                self.draw_player(player, positions[i], is_current, show_cards, game.phase)

    def draw_message(self, message: str):
        if not message:
            return
        text = self.font_large.render(message, True, COLORS["text_white"])
        text_rect = text.get_rect(center=(WINDOW_WIDTH // 2, WINDOW_HEIGHT - 20))

        bg = pygame.Surface((text_rect.width + 30, text_rect.height + 10), pygame.SRCALPHA)
        pygame.draw.rect(bg, (0, 0, 0, 150), bg.get_rect(), border_radius=8)
        self.screen.blit(bg, (text_rect.x - 15, text_rect.y - 5))
        self.screen.blit(text, text_rect)

    def draw_phase_indicator(self, phase: GamePhase):
        phase_text = self.font_small.render(f"阶段: {phase.value}", True, COLORS["text_dim"])
        self.screen.blit(phase_text, (15, 15))

    def draw_hand_results(self, results: list[dict]):
        if not results:
            return

        cx = WINDOW_WIDTH // 2
        cy = TABLE_CENTER[1]

        overlay = pygame.Surface((WINDOW_WIDTH, WINDOW_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 80))
        self.screen.blit(overlay, (0, 0))

        box_w = 400
        box_h = 50 + len(results) * 40
        box_x = cx - box_w // 2
        box_y = cy - box_h // 2

        s = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
        pygame.draw.rect(s, (20, 20, 40, 230), s.get_rect(), border_radius=12)
        pygame.draw.rect(s, (100, 160, 100, 200), s.get_rect(), width=2, border_radius=12)
        self.screen.blit(s, (box_x, box_y))

        title = self.font_large.render("本局结果", True, COLORS["gold"])
        title_rect = title.get_rect(center=(cx, box_y + 25))
        self.screen.blit(title, title_rect)

        for i, result in enumerate(results):
            p = result["player"]
            winnings = result["winnings"]
            desc = result["hand_desc"]
            line = f"{p.name}: +{winnings}  ({desc})"
            line_text = self.font_medium.render(line, True, COLORS["text_white"])
            line_rect = line_text.get_rect(center=(cx, box_y + 60 + i * 40))
            self.screen.blit(line_text, line_rect)

    def draw_title_screen(self):
        self.draw_background()
        self.draw_table()

        title = self.font_title.render("德州扑克", True, COLORS["gold"])
        title_rect = title.get_rect(center=(WINDOW_WIDTH // 2, WINDOW_HEIGHT // 2 - 40))
        self.screen.blit(title, title_rect)

        sub = self.font_medium.render("Texas Hold'em Poker", True, COLORS["text_dim"])
        sub_rect = sub.get_rect(center=(WINDOW_WIDTH // 2, WINDOW_HEIGHT // 2))
        self.screen.blit(sub, sub_rect)

    def render_game(self, game: Game, show_results: bool = False):
        self.draw_background()
        self.draw_table()
        self.draw_community_cards(game.community_cards)
        self.draw_pot(game.pot, game.phase)
        self.draw_players(game)
        self.draw_phase_indicator(game.phase)
        self.draw_message(game.message)

        if show_results and game.hand_results:
            self.draw_hand_results(game.hand_results)
