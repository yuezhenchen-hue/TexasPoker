from __future__ import annotations

import sys
import time

import pygame

from poker.game import Game, GamePhase
from poker.player import Action
from ui.renderer import Renderer, WINDOW_WIDTH, WINDOW_HEIGHT, COLORS
from ui.button import Button, Slider


FPS = 60
AI_DELAY_MS = 600


class TexasPokerApp:
    def __init__(self):
        pygame.init()
        pygame.display.set_caption("德州扑克 — Texas Hold'em")
        self.screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
        self.clock = pygame.time.Clock()
        self.renderer = Renderer(self.screen)
        self.game = Game()
        self.running = True

        self.ai_timer = 0
        self.show_results = False
        self.results_timer = 0
        self.results_display_ms = 3000

        self._create_buttons()
        self.raise_slider = Slider(0, 0, 200, 14, 20, 1000, 40, step=10)
        self.raise_slider.visible = False

    def _create_buttons(self):
        btn_y = WINDOW_HEIGHT - 180
        btn_w, btn_h = 100, 40
        gap = 15
        total_w = btn_w * 5 + gap * 4
        start_x = (WINDOW_WIDTH - total_w) // 2

        self.btn_fold = Button(start_x, btn_y, btn_w, btn_h, "弃牌",
                               color=(160, 50, 50), hover_color=(200, 70, 70))
        self.btn_check = Button(start_x + (btn_w + gap), btn_y, btn_w, btn_h, "过牌",
                                color=(50, 120, 160), hover_color=(70, 150, 200))
        self.btn_call = Button(start_x + (btn_w + gap) * 2, btn_y, btn_w, btn_h, "跟注",
                               color=(50, 140, 100), hover_color=(70, 180, 130))
        self.btn_raise = Button(start_x + (btn_w + gap) * 3, btn_y, btn_w, btn_h, "加注",
                                color=(160, 130, 40), hover_color=(200, 170, 60))
        self.btn_allin = Button(start_x + (btn_w + gap) * 4, btn_y, btn_w, btn_h, "全下",
                                color=(180, 40, 40), hover_color=(220, 60, 60))

        self.action_buttons = [self.btn_fold, self.btn_check, self.btn_call, self.btn_raise, self.btn_allin]

        self.btn_start = Button(
            WINDOW_WIDTH // 2 - 75, WINDOW_HEIGHT // 2 + 40, 150, 50, "开始游戏",
            color=(60, 140, 60), hover_color=(80, 180, 80), font_size=24
        )

        self.btn_next = Button(
            WINDOW_WIDTH // 2 - 75, WINDOW_HEIGHT // 2 + 110, 150, 44, "下一局",
            color=(60, 120, 160), hover_color=(80, 150, 200)
        )
        self.btn_next.visible = False

    def _update_action_buttons(self):
        if not self.game.waiting_for_human or self.game.phase in (GamePhase.WAITING, GamePhase.HAND_OVER, GamePhase.SHOWDOWN):
            for btn in self.action_buttons:
                btn.visible = False
            self.raise_slider.visible = False
            return

        options = self.game.get_human_options()
        action_types = {a for a, _ in options}
        to_call = self.game.current_bet - self.game.human.current_bet

        self.btn_fold.visible = True
        self.btn_fold.enabled = Action.FOLD in action_types

        self.btn_check.visible = Action.CHECK in action_types
        self.btn_check.enabled = True

        self.btn_call.visible = Action.CALL in action_types
        self.btn_call.enabled = True
        if Action.CALL in action_types:
            self.btn_call.text = f"跟注 {to_call}"

        can_raise = Action.RAISE in action_types
        self.btn_raise.visible = can_raise
        self.btn_raise.enabled = can_raise

        if can_raise:
            min_r = self.game.min_raise
            max_r = self.game.human.chips - to_call
            self.raise_slider.min_val = min_r
            self.raise_slider.max_val = max(min_r, max_r)
            self.raise_slider.value = min(self.raise_slider.value, self.raise_slider.max_val)
            self.raise_slider.value = max(self.raise_slider.value, self.raise_slider.min_val)
            self.raise_slider.step = max(10, min_r // 2)
            slider_x = self.btn_raise.rect.x - 60
            slider_y = self.btn_raise.rect.y - 30
            self.raise_slider.rect.x = slider_x
            self.raise_slider.rect.y = slider_y
            self.raise_slider.visible = True
            self.btn_raise.text = f"加注 {self.raise_slider.value}"
        else:
            self.raise_slider.visible = False

        self.btn_allin.visible = Action.ALL_IN in action_types
        self.btn_allin.enabled = True
        self.btn_allin.text = f"全下 {self.game.human.chips}"

    def _handle_events(self):
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
                return

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.running = False
                    return

            if self.game.phase == GamePhase.WAITING:
                if self.btn_start.handle_event(event):
                    self.game.start_new_hand()
                    self.btn_start.visible = False
                    self.show_results = False
                continue

            if self.game.phase == GamePhase.HAND_OVER:
                if self.btn_next.handle_event(event):
                    self.show_results = False
                    self.game.start_new_hand()
                    self.btn_next.visible = False
                continue

            if self.game.waiting_for_human:
                self.raise_slider.handle_event(event)

                if self.btn_fold.handle_event(event):
                    self.game.process_human_action(Action.FOLD)
                elif self.btn_check.handle_event(event):
                    self.game.process_human_action(Action.CHECK)
                elif self.btn_call.handle_event(event):
                    to_call = self.game.current_bet - self.game.human.current_bet
                    self.game.process_human_action(Action.CALL, to_call)
                elif self.btn_raise.handle_event(event):
                    self.game.process_human_action(Action.RAISE, self.raise_slider.value)
                elif self.btn_allin.handle_event(event):
                    self.game.process_human_action(Action.ALL_IN, self.game.human.chips)

            for btn in self.action_buttons:
                if event.type == pygame.MOUSEMOTION:
                    btn.is_hovered = btn.rect.collidepoint(event.pos) if btn.visible else False
            if self.btn_start.visible and event.type == pygame.MOUSEMOTION:
                self.btn_start.is_hovered = self.btn_start.rect.collidepoint(event.pos)
            if self.btn_next.visible and event.type == pygame.MOUSEMOTION:
                self.btn_next.is_hovered = self.btn_next.rect.collidepoint(event.pos)

    def _update(self, dt_ms: int):
        if self.game.phase == GamePhase.HAND_OVER:
            if not self.show_results:
                self.show_results = True
                self.results_timer = 0
                self.btn_next.visible = True
            return

        if self.game.phase == GamePhase.SHOWDOWN:
            self.show_results = True
            self.results_timer += dt_ms
            if self.results_timer > self.results_display_ms:
                self.game.phase = GamePhase.HAND_OVER
                self.btn_next.visible = True
            return

        if self.game.waiting_for_human:
            return

        if self.game.phase in (GamePhase.WAITING,):
            return

        self.ai_timer += dt_ms
        if self.ai_timer >= AI_DELAY_MS:
            self.ai_timer = 0
            player = self.game.current_player
            if player and not player.is_human and player.is_active:
                self.game.process_ai_turn()

    def _draw(self):
        if self.game.phase == GamePhase.WAITING:
            self.renderer.draw_title_screen()
            self.btn_start.draw(self.screen, self.renderer.font_large)
        else:
            self.renderer.render_game(self.game, show_results=self.show_results)
            self._update_action_buttons()

            for btn in self.action_buttons:
                btn.draw(self.screen, self.renderer.font_medium)

            self.raise_slider.draw(self.screen, self.renderer.font_small)

            if self.btn_next.visible:
                self.btn_next.draw(self.screen, self.renderer.font_medium)

        hand_info = self.renderer.font_small.render(
            f"第 {self.game.hand_number} 局  |  玩家: {len(self.game.players)}",
            True, COLORS["text_dim"]
        )
        self.screen.blit(hand_info, (WINDOW_WIDTH - hand_info.get_width() - 15, 15))

        pygame.display.flip()

    def run(self):
        while self.running:
            dt_ms = self.clock.tick(FPS)
            self._handle_events()
            self._update(dt_ms)
            self._draw()

        pygame.quit()
        sys.exit()


def main():
    app = TexasPokerApp()
    app.run()


if __name__ == "__main__":
    main()
