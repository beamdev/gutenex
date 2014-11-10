defmodule Gutenex.PDF.Builders.PageBuilder do
  alias Gutenex.PDF.Context
  alias Gutenex.PDF.RenderContext

  @doc """
    Pages are built into two objects
    The first contains the stream of the page contents
    The second is a dictionary describing the page, a reference to the
    page tree, and a reference to the page contents
  """
  def build({%RenderContext{}=render_context, %Context{}=context}) do
    updated_render_context = build_pages(render_context, context.pages)
    |> add_page_references_to_page_tree
    {updated_render_context, context}
  end

  defp build_pages(render_context, []=_pages_left_to_build) do
    %RenderContext{
      render_context |
      page_references: Enum.reverse(render_context.page_references),
      page_objects: Enum.reverse(render_context.page_objects)
    }
  end

  defp build_pages(render_context, [page|pages_left_to_build]) do
    render_context = add_page(render_context, page)
    |> add_page_summary
    # We are adding two objects so next index should be two greater than start
    build_pages(render_context, pages_left_to_build)
  end

  defp add_page(%RenderContext{page_objects: page_objects}=render_context, page) do
    %RenderContext{
      RenderContext.next_index(render_context) |
      page_objects: [ page_object(render_context, page) | page_objects ]
    }
  end

  defp page_object(render_context, page) do
    {
      {:obj, render_context.current_index, render_context.generation_number},
      {:stream, page}
    }
  end

  defp add_page_summary(%RenderContext{}=render_context) do
    %RenderContext{
      RenderContext.next_index(render_context) |
      page_objects: [page_summary(render_context) | render_context.page_objects],
      page_references: [page_reference(render_context) | render_context.page_references]
    }
  end

  defp page_summary(render_context) do
    {
      {:obj, render_context.current_index, render_context.generation_number},
      {:dict, %{
        "Type" => {:name, "Page"},
        "Parent" => render_context.page_tree_reference,
        "Contents" => {:ptr, render_context.current_index - 1, render_context.generation_number}
      }}
    }
  end

  defp page_reference(render_context) do
    {:ptr, render_context.current_index, render_context.generation_number}
  end

  defp add_page_references_to_page_tree(render_context) do
    {
      {:obj, _, _}=page_tree_obj,
      {:dict, page_tree_dict}
    } = render_context.page_tree
    updated_page_tree = Map.put(page_tree_dict, "Kids", {:array, render_context.page_references})
    |> Map.put("Count", length(render_context.page_references))
    %RenderContext{
      render_context |
      page_tree: {
        page_tree_obj,
        {:dict, updated_page_tree}
      }
    }
  end
end
