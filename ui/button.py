import pygame


class Button:
    def __init__(
        self,
        x: int,
        y: int,
        width: int,
        height: int,
        text: str,
        color: tuple = (60, 140, 60),
        hover_color: tuple = (80, 180, 80),
        text_color: tuple = (255, 255, 255),
        font_size: int = 20,
        border_radius: int = 8,
    ):
        self.rect = pygame.Rect(x, y, width, height)
        self.text = text
        self.color = color
        self.hover_color = hover_color
        self.text_color = text_color
        self.font_size = font_size
        self.border_radius = border_radius
        self.is_hovered = False
        self.visible = True
        self.enabled = True

    def draw(self, surface: pygame.Surface, font: pygame.font.Font):
        if not self.visible:
            return

        color = self.hover_color if self.is_hovered and self.enabled else self.color
        if not self.enabled:
            color = (100, 100, 100)

        pygame.draw.rect(surface, color, self.rect, border_radius=self.border_radius)
        pygame.draw.rect(surface, (255, 255, 255, 80), self.rect, width=2, border_radius=self.border_radius)

        text_surface = font.render(self.text, True, self.text_color)
        text_rect = text_surface.get_rect(center=self.rect.center)
        surface.blit(text_surface, text_rect)

    def handle_event(self, event: pygame.event.Event) -> bool:
        if not self.visible or not self.enabled:
            return False

        if event.type == pygame.MOUSEMOTION:
            self.is_hovered = self.rect.collidepoint(event.pos)

        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if self.rect.collidepoint(event.pos):
                return True

        return False


class Slider:
    def __init__(self, x, y, width, height, min_val, max_val, initial, step=10):
        self.rect = pygame.Rect(x, y, width, height)
        self.min_val = min_val
        self.max_val = max(min_val, max_val)
        self.value = min(max(initial, min_val), self.max_val)
        self.step = step
        self.dragging = False
        self.visible = True
        self.handle_radius = height // 2 + 4
        self.track_color = (80, 80, 80)
        self.fill_color = (60, 160, 60)
        self.handle_color = (240, 240, 240)

    @property
    def handle_x(self):
        if self.max_val == self.min_val:
            return self.rect.x
        ratio = (self.value - self.min_val) / (self.max_val - self.min_val)
        return self.rect.x + int(ratio * self.rect.width)

    def draw(self, surface, font):
        if not self.visible:
            return

        cy = self.rect.centery
        pygame.draw.rect(surface, self.track_color, self.rect, border_radius=4)

        fill_rect = pygame.Rect(self.rect.x, self.rect.y, self.handle_x - self.rect.x, self.rect.height)
        pygame.draw.rect(surface, self.fill_color, fill_rect, border_radius=4)

        pygame.draw.circle(surface, self.handle_color, (self.handle_x, cy), self.handle_radius)
        pygame.draw.circle(surface, (60, 60, 60), (self.handle_x, cy), self.handle_radius, 2)

        val_text = font.render(str(self.value), True, (255, 255, 255))
        surface.blit(val_text, (self.rect.right + 10, cy - val_text.get_height() // 2))

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            hx = self.handle_x
            cy = self.rect.centery
            if (event.pos[0] - hx) ** 2 + (event.pos[1] - cy) ** 2 <= (self.handle_radius + 5) ** 2:
                self.dragging = True
            elif self.rect.collidepoint(event.pos):
                self._update_value(event.pos[0])

        elif event.type == pygame.MOUSEBUTTONUP:
            self.dragging = False

        elif event.type == pygame.MOUSEMOTION and self.dragging:
            self._update_value(event.pos[0])

    def _update_value(self, mouse_x):
        ratio = (mouse_x - self.rect.x) / max(1, self.rect.width)
        ratio = max(0.0, min(1.0, ratio))
        raw = self.min_val + ratio * (self.max_val - self.min_val)
        self.value = int(round(raw / self.step) * self.step)
        self.value = max(self.min_val, min(self.max_val, self.value))
