defmodule Switchyard.TUI.ScreenUI do
  @moduledoc false

  alias ExRatatui.Frame
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Widgets.{Block, Paragraph, Popup}

  @spec root_area(Frame.t()) :: Rect.t()
  def root_area(%Frame{width: width, height: height}) do
    %Rect{x: 0, y: 0, width: width, height: height}
  end

  @spec pane(String.t(), [String.t()] | String.t(), keyword()) :: Paragraph.t()
  def pane(title, lines, opts \\ []) do
    %Paragraph{
      text: if(is_list(lines), do: Enum.join(lines, "\n"), else: lines),
      wrap: Keyword.get(opts, :wrap, true),
      style: Keyword.get(opts, :style, %Style{fg: :white}),
      block: %Block{
        title: title,
        borders: [:all],
        border_type: :rounded,
        border_style: %Style{fg: Keyword.get(opts, :border_fg, :cyan)},
        padding: {1, 1, 0, 0}
      }
    }
  end

  @spec text_widget(String.t(), keyword()) :: Paragraph.t()
  def text_widget(text, opts \\ []) do
    %Paragraph{
      text: text,
      wrap: Keyword.get(opts, :wrap, true),
      style: Keyword.get(opts, :style, %Style{fg: :white}),
      alignment: Keyword.get(opts, :alignment, :left),
      block: Keyword.get(opts, :block)
    }
  end

  @spec popup(String.t(), [String.t()], Frame.t(), keyword()) ::
          {Popup.t(), Rect.t()}
  def popup(title, lines, %Frame{} = frame, opts \\ []) do
    area = root_area(frame)

    popup = %Popup{
      content: text_widget(Enum.join(lines, "\n"), wrap: true),
      block: %Block{
        title: title,
        borders: [:all],
        border_type: :rounded,
        border_style: %Style{fg: Keyword.get(opts, :border_fg, :yellow)},
        padding: {1, 1, 1, 1}
      },
      fixed_width: min(max(frame.width - 6, 48), 110),
      fixed_height: min(max(length(lines) + 4, 12), max(frame.height - 6, 12))
    }

    {popup, area}
  end

  def header_style, do: %Style{fg: :cyan, modifiers: [:bold]}
  def meta_style, do: %Style{fg: :dark_gray}
  def status_style(:error), do: %Style{fg: :red, modifiers: [:bold]}
  def status_style(:warn), do: %Style{fg: :yellow}
  def status_style(_severity), do: %Style{fg: :green}
end
