defmodule KitchenSink.Algorithms do
  @moduledoc """
  This is a collection of algorithms.

  ## The binary search `fit` function

  The search is controlled by the `fit` function which is passed the value to
  test and returns `:ok` if the value is good enough, `:high` if the next
  value to test should be higher, or `:low` if the next value should be
  lower.
  """

  @type binary_search_position :: integer
  @type binary_search_fit_func :: (binary_search_position, any -> :ok | :high | :low)
  @type binary_search_strategy :: (:midpoint | :interval | function)
  @type binary_search_result :: {:ok, binary_search_position} | :not_found

  @type binary_interval_search_position :: number
  @type binary_interval_search_fit_func :: (binary_interval_search_position, any -> :ok | :high | :low)
  @type binary_interval_search_result :: {:ok, binary_interval_search_position} | :not_found

  @doc """
  `binary_search` performs a binary search over a range.

  The binary search function requires a midpoint strategy to be specified. If no strategy
  is specified, it defaults to `:midpoint`

  ## Examples using the `:midpoint` strategy

      iex> names = ~w(Adrian Bill Robert Tony) # Sorted!
      iex> search_names = fn(position, target) ->
      ...>   current = Enum.at(names, position)
      ...>   cond do
      ...>     current < target -> :high
      ...>     current == target -> :ok
      ...>     current > target -> :low
      ...>   end
      ...> end
      iex>
      iex> Algorithms.binary_search(0, 3, search_names, "Tony", :midpoint)
      {:ok, 3}
      iex> Algorithms.binary_search(0, 3, search_names, "Phil", :midpoint)
      {:not_found, 2}

  It is *possible* to override the calculation of the midpoint for the binary
  search, and that is "...left as an exercise for the reader."

  It is also possible to binary-search multiple ranges at the same time, in case you are
  trying to find some balance between of a number of variable factors.

  ## Example (albeit a contrived one) of searching multiple ranges simultaneously
    iex>   solve = fn (pos, desired_result) ->
    ...>     result = Enum.reduce(pos, fn (x, acc) -> x + acc end)
    ...>     cond do
    ...>       result < desired_result -> :high
    ...>       result == desired_result -> :ok
    ...>       result > desired_result -> :low
    ...>     end
    ...>   end
    iex> Algorithms.hybrid_binary_search([2..40, 20..100], solve, 27, :midpoint)
    {:ok, [3, 24]}

  ## Examples using the `:interval` strategy

  To see where *y = 10 + x³* and *y = 1000 + x²* intersect

      iex> solve = fn(position, _) ->
      ...>   y1 = 10 + :math.pow(position, 3)
      ...>   y2 = 1000 + :math.pow(position, 2)
      ...>   difference = y1 - y2
      ...>
      ...>   epsilon = 0.0001
      ...>
      ...>   cond do
      ...>     abs(difference) < epsilon -> :ok
      ...>     difference > 0.0 -> :low
      ...>     difference < 0.0 -> :high
      ...>   end
      ...> end
      iex>
      iex> {:ok, result} = Algorithms.binary_search(1, 100, solve, 0.0, :interval)
      iex> Float.round(result, 6)
      10.311285
  """
  def hybrid_binary_search(range_list, fit, target, strategy \\ :midpoint) when is_function(fit) and is_list(range_list) do
    {range_start_list, range_finish_list} =
      range_list
      |> Enum.reduce(
        {[], []},
        fn (range, {start_list, finish_list}) ->
          start..finish = range
          {start_list ++ [start], finish_list ++ [finish]}
        end
      )

    binary_search(range_start_list, range_finish_list, fit, target, strategy)
  end

  def binary_search(start, finish, fit, target, strategy \\ :midpoint)
  @spec binary_search(
    binary_search_position,
    binary_search_position,
    binary_search_fit_func,
    any,
    binary_search_strategy
  ) :: binary_search_result
  def binary_search(
    range_start_list,
    range_finish_list,
    fit,
    target,
    strategy
  ) when is_function(fit) and is_list(range_start_list) and is_list(range_finish_list) do
    {start_list, finish_list} = ensure_order(range_start_list, range_finish_list)
    do_binary_search(start_list, finish_list, fit, target, strategy)
  end
  def binary_search(range_start, range_finish, fit, target, strategy) when is_function(fit) do
    binary_search([range_start], [range_finish], fit, target, strategy)
  end

  defp ensure_order(same, same) do
    {same, same}
  end
  defp ensure_order(start_list, finish_list) do
    [a | start_rest] = start_list
    [b | finish_rest] = finish_list
    {start, finish} =
      if a < b do
        {[a], [b]}
      else
        {[b], [a]}
      end
    {final_start, final_finish} = ensure_order(start_rest, finish_rest)
    {start ++ final_start, finish ++ final_finish}
  end

  defp do_binary_search(list_start, list_end, fit, target, :midpoint) do
    do_binary_search(list_start, list_end, fit, target, &binary_search_midpoint/2)
  end
  defp do_binary_search(list_start, list_end, fit, target, :interval) do
    do_binary_search(list_start, list_end, fit, target, &binary_search_interval/2)
  end
  defp do_binary_search(position, position, fit, target, _), do: ok_or_not_found(position, fit, target)
  defp do_binary_search(list_start, list_end, fit, target, strategy) when is_function(strategy) do
    {{a, b}, list_mid, {c, d}} = strategy.(list_start, list_end)
    # Maintain backward-compatibility
    mid_fit_check = if Kernel.length(list_mid) === 1, do: List.first(list_mid), else: list_mid
    case fit.(mid_fit_check, target) do
      :ok -> {:ok, mid_fit_check}
      :high -> do_binary_search(c, d, fit, target, strategy)
      :low -> do_binary_search(a, b, fit, target, strategy)
    end
  end

  defp binary_search_midpoint(list_start, list_end) do
    list_mid =
      list_start
      |> Enum.zip(list_end)
      |> Enum.map(fn {start, finish} -> start + div(finish - start, 2) end)

    range_after_mid =
      list_mid
      |> Enum.zip(list_end)
      |> Enum.reduce({[], []}, fn {mid, finish}, {a, b} -> {[bounded_increment(mid, finish) | a], [finish | b]} end)

    range_before_mid =
      list_start
      |> Enum.zip(list_mid)
      |> Enum.reduce({[], []}, fn {start, mid}, {a, b} -> {[start | a], [bounded_decrement(mid, start) | b]} end)

    {range_before_mid, list_mid |> Enum.reverse(), range_after_mid}
  end

  defp binary_search_interval(list_start, list_end) do
    list_mid =
      list_start
      |> Enum.zip(list_end)
      |> Enum.map(fn {start, finish} -> start + (finish - start) / 2.0 end)

    range_after_mid =
      list_mid
      |> Enum.zip(list_end)
      |> Enum.reduce({[], []}, fn {mid, finish}, {a, b} -> {[mid | a], [finish | b]} end)

    range_before_mid =
      list_start
      |> Enum.zip(list_mid)
      |> Enum.reduce({[], []}, fn {start, mid}, {a, b} -> {[start | a], [mid | b]} end)

    {range_before_mid, list_mid, range_after_mid}
  end

  defp bounded_increment(to_increment, bound) do
    min(to_increment + 1, bound)
  end

  defp bounded_decrement(to_decrement, bound) do
    max(to_decrement - 1, bound)
  end

  defp ok_or_not_found(list, fit, target) do
    # Maintain backward-compatibility
    fit_check = if Kernel.length(list) === 1, do: List.first(list), else: list
    case fit.(fit_check, target) do
      :ok -> {:ok, fit_check}
      _ -> {:not_found, fit_check}
    end
  end
end
