defmodule MapGen do
  @moduledoc """
  Documentation for `MapGen`.
  """

  def new(max_x, max_y, min) do
    map = %{bounds: {max_x, max_y, min}, coord_set: generate(max_x, max_y, min)}
    island_count = max_x + max_y

    map
    |> extend()
    |> add_islands(island_count)
    |> fill_unreachable()
    |> add_spawns(40)
    |> print()
  end

  @doc """
  Random generation.
  """
  def generate(max_x, max_y, min) do
    west_border = for y <- min..max_y, do: {min, y}
    north_border = for x <- min..max_x, do: {x, min}
    south_border = for x <- min..max_x, do: {x, max_y}
    east_border = for y <- min..max_y, do: {max_x, y}

    MapSet.new()
    |> then(&Enum.reduce(west_border, &1, fn coord, set -> MapSet.put(set, coord) end))
    |> then(&Enum.reduce(north_border, &1, fn coord, set -> MapSet.put(set, coord) end))
    |> then(&Enum.reduce(south_border, &1, fn coord, set -> MapSet.put(set, coord) end))
    |> then(&Enum.reduce(east_border, &1, fn coord, set -> MapSet.put(set, coord) end))
  end

  def extend(%{coord_set: set, bounds: {max_x, max_y, min}} = map) do
    new_set =
      Enum.reduce(set, set, fn
        {^min, ^min}, acc -> acc
        {^max_x, ^max_y}, acc -> acc
        {^min, ^max_y}, acc -> acc
        {^max_x, ^min}, acc -> acc
        {^min, _} = coord, acc -> coord |> extend_coords(:east) |> Enum.reduce(acc, &MapSet.put(&2, &1))
        {^max_x, _} = coord, acc -> coord |> extend_coords(:west) |> Enum.reduce(acc, &MapSet.put(&2, &1))
        {_, ^min} = coord, acc -> coord |> extend_coords(:south) |> Enum.reduce(acc, &MapSet.put(&2, &1))
        {_, ^max_y} = coord, acc -> coord |> extend_coords(:north) |> Enum.reduce(acc, &MapSet.put(&2, &1))
      end)

    %{map | coord_set: new_set}
  end

  defp extend_coords({x, y}, :east) do
    case Enum.random(1..25) do
      n when n <= 4 -> [{x + 1, y}, {x, y + 1}, {x, y - 1}] ++ extend_coords({x + 1, y}, :east)
      n when n <= 5 -> [{x + 1, y}, {x, y + 1}] ++ extend_coords({x + 1, y}, :east)
      n when n <= 6 -> [{x + 1, y}, {x, y - 1}] ++ extend_coords({x + 1, y}, :east)
      n when n <= 11 -> [{x + 1, y}] ++ extend_coords({x + 1, y}, :east)
      _ -> []
    end
  end

  defp extend_coords({x, y}, :west) do
    case Enum.random(1..25) do
      n when n <= 4 -> [{x - 1, y}, {x, y + 1}, {x, y - 1}] ++ extend_coords({x - 1, y}, :west)
      n when n <= 6 -> [{x - 1, y}, {x, y + 1}] ++ extend_coords({x - 1, y}, :west)
      n when n <= 8 -> [{x - 1, y}, {x, y - 1}] ++ extend_coords({x - 1, y}, :west)
      n when n <= 11 -> [{x - 1, y}] ++ extend_coords({x - 1, y}, :west)
      _ -> []
    end
  end

  defp extend_coords({x, y}, :north) do
    case Enum.random(1..25) do
      n when n <= 4 -> [{x, y - 1}, {x + 1, y}, {x - 1, y}] ++ extend_coords({x, y - 1}, :north)
      n when n <= 6 -> [{x, y - 1}, {x + 1, y}] ++ extend_coords({x, y - 1}, :north)
      n when n <= 8 -> [{x, y - 1}, {x - 1, y}] ++ extend_coords({x, y - 1}, :north)
      n when n <= 11 -> [{x, y - 1}] ++ extend_coords({x, y - 1}, :north)
      _ -> []
    end
  end

  defp extend_coords({x, y}, :south) do
    case Enum.random(1..25) do
      n when n <= 4 -> [{x, y + 1}, {x + 1, y}, {x - 1, y}] ++ extend_coords({x, y + 1}, :south)
      n when n <= 6 -> [{x, y + 1}, {x + 1, y}] ++ extend_coords({x, y + 1}, :south)
      n when n <= 8 -> [{x, y + 1}, {x - 1, y}] ++ extend_coords({x, y + 1}, :south)
      n when n <= 11 -> [{x, y + 1}] ++ extend_coords({x, y + 1}, :south)
      _ -> []
    end
  end

  @shapes %{
    round: [{0, 0}, {0, 1}, {1, 1}, {1, 0}],
    flat: [{0, 0}, {1, 0}, {2, 0}],
    tall: [{0, 0}, {0, 1}, {0, 2}],
    dot: [{0, 0}]
  }

  def add_islands(%{bounds: {max_x, max_y, min}} = map, island_count) do
    new_coords =
      1..island_count
      |> Enum.map(fn _ ->
        shape = Enum.random([:round, :flat, :tall, :dot])
        coords = @shapes[shape]
        x_offset = Enum.random((min + 3)..(max_x - 3))
        y_offset = Enum.random((min + 3)..(max_y - 3))

        Enum.map(coords, fn {x, y} -> {x + x_offset, y + y_offset} end)
      end)
      |> List.flatten()
      |> MapSet.new()
      |> MapSet.union(map.coord_set)

    %{map | coord_set: new_coords}
  end

  def fill_unreachable(%{coord_set: set, bounds: {max_x, max_y, min}} = map) do
    empty_coords =
      for x <- min..max_x,
          y <- min..max_y,
          !MapSet.member?(set, {x, y}) do
        {x, y}
      end

    Enum.reduce(empty_coords, map, fn coord, acc ->
      if unreachable?(coord, acc) do
        %{acc | coord_set: MapSet.put(acc.coord_set, coord)}
      else
        acc
      end
    end)
  end

  def unreachable?(coord, map) do
    check_unreachable([coord], map.coord_set, MapSet.new(), 3)
  end

  def check_unreachable([], _, _, _), do: true
  def check_unreachable(_, _, _, 0), do: false

  def check_unreachable(to_check, blocked, seen, countdown) do
    to_check
    |> Enum.flat_map(fn {x, y} ->
      [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]
      |> Enum.reject(&MapSet.member?(seen, &1))
      |> Enum.reject(&MapSet.member?(blocked, &1))
    end)
    |> check_unreachable(blocked, MapSet.union(seen, MapSet.new(to_check)), countdown - 1)
  end

  def add_spawns(%{coord_set: set, bounds: {max_x, max_y, min}} = map, spawn_count) do
    possible_spawns =
      for x <- min..max_x,
          y <- min..max_y,
          !MapSet.member?(set, {x, y}) do
        {x, y}
      end

    spawns =
      possible_spawns
      |> Enum.take_random(spawn_count)
      |> MapSet.new()

    Map.put(map, :spawn_points, spawns)
  end

  @doc """
  Prints the coord set.
  """
  def print(%{bounds: {_, _, min}} = map) do
    do_print({min, min}, map, [])
  end

  defp do_print({_, y}, %{bounds: {_, bound_y, _}}, output) when y > bound_y, do: IO.puts(output)

  defp do_print({x, y}, %{bounds: {bound_x, _, min}} = map, output) when x > bound_x,
    do: do_print({min, y + 1}, map, ["\n" | output])

  defp do_print({x, y}, map, output) do
    new_output =
      cond do
        MapSet.member?(map.coord_set, {x, y}) -> ["X" | output]
        MapSet.member?(map.spawn_points, {x, y}) -> ["@" | output]
        :otherwise -> [" " | output]
      end

    do_print({x + 1, y}, map, new_output)
  end
end
