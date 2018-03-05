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

  ## Example (albeit a contrived one) of searching multiple ranges simultaneously
    iex>   solve = fn (pos, desired_result) ->
    ...>     result = Enum.reduce(pos, fn (x, acc) -> x + acc end)
    ...>     cond do
    ...>       result < desired_result -> :high
    ...>       result == desired_result -> :ok
    ...>       result > desired_result -> :low
    ...>     end
    ...>   end
    iex> Algorithms.hybrid_binary_search([{2, 40, :asc}, {20, 100, :desc}], solve, 27, :midpoint)
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
    do_hybrid_binary_search(range_list, fit, target, strategy)
  end

  defp do_hybrid_binary_search([{start, finish, direction} | _] = range_list, fit, target, strategy) do
    # Already in the format we desire
    do_binary_search(range_list, fit, target, strategy)
  end
  defp do_binary_search(range_list, fit, target, strategy) do
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
    combined_list =
      [start_list, finish_list]
      |> Enum.zip()
      |> Enum.map(fn {start, finish} -> {start, finish, :asc} end)
    do_binary_search(combined_list, fit, target, strategy)
  end
  def binary_search(range_start, range_finish, fit, target, strategy) when is_function(fit) do
    # IO.puts("B")
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

  defp do_binary_search(list, fit, target, :midpoint) do
    do_binary_search(list, fit, target, &binary_search_midpoint/3)
  end
  defp do_binary_search(list, fit, target, :interval) do
    do_binary_search(list, fit, target, &binary_search_interval/3)
  end
  defp do_binary_search(list, fit, target, strategy) when is_function(strategy) do
    if search_complete(list) do
      values =
      list
      |> Enum.reduce([], fn {pos, pos, _}, acc -> [pos | acc] end)
      ok_or_not_found(values, fit, target)
    else
      ok_or_direction(list, fit, target, strategy)
    end
  end

  # Run the fit check.
  #
  # If it fails, determine the correct direction to go, :high or :low
  # (not to be confused with :asc or :desc)
  defp ok_or_direction(list, fit, target, strategy) do
    # Strategy - bisect the range(s)
    # Problem: We need to know the new direction (if any) in order to choose
    # the new ranges, but we need to use the strategy in order to choose the new ranges
    {result, list_mid} = strategy.(list, fit, target)

    # At this point, each tuple should have its "next" range, since the strategy
    # is responsible for both finding the midpoint and finding the new range

    # Maintain backward-compatibility for single-range cases
    # mid_fit_check = mid_fit_check(list_mid)

    # Check the bisected range(s) with the fit function
    # case fit.(mid_fit_check, target) do
    #   :ok -> {:ok, mid_fit_check}
    #   :high -> do_binary_search(process(list_mid, :high), fit, target, strategy)
    #   :low -> do_binary_search(process(list_mid, :low), fit, target, strategy)
    # end

    case result do
      :ok -> {:ok, list_mid}
      :high -> do_binary_search(list_mid, fit, target, strategy)
      :low -> do_binary_search(list_mid, fit, target, strategy)
    end
  end

  defp mid_fit_check([{_, mid, _, _}]) do
    mid
  end
  defp mid_fit_check(list) when is_list(list) do
    list
    |> Enum.reduce([], fn {_, mid, _, _}, acc -> acc ++ [mid] end)
  end

  defp process(list, direction, bounding) when is_list(list) do

    Enum.map(list, fn range -> direction(range, direction, bounding) end)
  end
  defp process(single, direction, bounding) do
    [single]
  end

  defp search_complete(list) do
    list
    |> Enum.reduce(false, fn {start, finish, _}, acc -> acc or start == finish end)
  end

  defp search_up(mid, finish, direction, :bounded) do
    {bounded_increment(mid, finish), finish, direction}
  end
  defp search_up(mid, finish, direction, :none) do
    {mid, finish, direction}
  end

  defp search_down(start, mid, direction, :bounded) do
    {start, bounded_decrement(mid, start), direction}
  end
  defp search_down(start, mid, direction, :none) do
    {start, mid, direction}
  end

  defp direction({start, mid, finish, :asc}, :high, bounding) do
    search_up(mid, finish, :asc, bounding)
  end
  defp direction({start, mid, finish, :asc}, :low, bounding) do
    search_down(start, mid, :asc, bounding)
  end
  defp direction({start, mid, finish, :desc}, :high, bounding) do
    search_down(start, mid, :desc, bounding)
  end
  defp direction({start, mid, finish, :desc}, :low, bounding) do
    search_up(mid, finish, :desc, bounding)
  end

  defp binary_search_midpoint(range_tuples, fit, target) do
    IO.inspect(range_tuples, label: :range_tuples)
    range_list =
      range_tuples
      |> Enum.map(fn {start, finish, direction} ->
        mid_strategy = {start, start + div(finish - start, 2), finish, direction}

        {start, start + div(finish - start, 2), finish, direction}
      end)
      |> IO.inspect(label: :range_list)

    # |> mid_fit_check() # Maintain backward-compatibility for single-range cases

    # Check the bisected range(s) with the fit function
    mids = mid_fit_check(range_list) |> IO.inspect(label: :mids, charlists: :as_list)
    fit_result = fit.(mids, target)

    case fit_result do
      :ok -> {:ok, mids}
      :high -> {:high, process(range_list, :high, :bounded)}
      :low -> {:low, process(range_list, :low, :bounded)}
    end
  end

  defp binary_search_interval(range_tuples, fit, target) do
    range_list =
      range_tuples
      |> Enum.map(fn {start, finish, direction} -> {start, start + (finish - start) / 2.0, finish, direction} end)

    # Check the bisected range(s) with the fit function
    fit_result = fit.(mid_fit_check(range_list), target)

    case fit_result do
      :ok -> {:ok, mid_fit_check(range_list)}
      :high -> {:high, process(range_list, :high, :none)}
      :low -> {:low, process(range_list, :low, :none)}
    end
  end

  # defp binary_search_midpoint(list_start, list_end, direction) do
  #   list_mid =
  #     list_start
  #     |> Enum.zip(list_end)
  #     |> Enum.map(fn {start, finish} -> start + div(finish - start, 2) end)

  #   range_after_mid =
  #     [list_start, list_mid, list_end, direction]
  #     |> Enum.zip()
  #     |> Enum.reduce(
  #       {[], [], []}, fn blob, acc -> direction(blob, acc) end)

  #     {range_before_mid, list_mid |> Enum.reverse(), range_after_mid, direction}
  # end
  # defp binary_search_midpoint(list_start, list_end) do
  #   list_mid =
  #     list_start
  #     |> Enum.zip(list_end)
  #     |> Enum.map(fn {start, finish} -> start + div(finish - start, 2) end)

  #   range_after_mid =
  #     list_mid
  #     |> Enum.zip(list_end)
  #     |> Enum.reduce({[], []}, fn {mid, finish}, {a, b} -> {[bounded_increment(mid, finish) | a], [finish | b]} end)

  #   range_before_mid =
  #     list_start
  #     |> Enum.zip(list_mid)
  #     |> Enum.reduce({[], []}, fn {start, mid}, {a, b} -> {[start | a], [bounded_decrement(mid, start) | b]} end)

  #   {range_before_mid, list_mid |> Enum.reverse(), range_after_mid}
  # end

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
