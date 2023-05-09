defmodule MapGen do
  @moduledoc """
  Documentation for `MapGen`.
  """

  def new(max_x, max_y) do
    set = generate(max_x, max_y)
    map = %{bounds: {max_x, max_y}, coord_set: set}

    map
    |> extend()
    |> add_islands(100)
    |> add_spawns(40)
    |> print()
  end

  @doc """
  Random generation.
  """
  def generate(max_x, max_y) do
    west_border = for y <- 0..max_y, do: {0, y}
    north_border = for x <- 1..max_x, do: {x, 0}
    south_border = for x <- 1..max_x, do: {x, max_y}
    east_border = for y <- 1..max_y, do: {max_x, y}

    MapSet.new()
    |> then(&Enum.reduce(west_border, &1, fn coord, set -> MapSet.put(set, coord) end))
    |> then(&Enum.reduce(north_border, &1, fn coord, set -> MapSet.put(set, coord) end))
    |> then(&Enum.reduce(south_border, &1, fn coord, set -> MapSet.put(set, coord) end))
    |> then(&Enum.reduce(east_border, &1, fn coord, set -> MapSet.put(set, coord) end))
  end

  def extend(%{coord_set: set, bounds: {max_x, max_y}} = map) do
    new_set =
      Enum.reduce(set, set, fn
        {0, 0}, acc -> acc
        {^max_x, ^max_y}, acc -> acc
        {0, ^max_y}, acc -> acc
        {^max_x, 0}, acc -> acc
        {0, _} = coord, acc -> coord |> extend_coords(:east) |> Enum.reduce(acc, &MapSet.put(&2, &1))
        {^max_x, _} = coord, acc -> coord |> extend_coords(:west) |> Enum.reduce(acc, &MapSet.put(&2, &1))
        {_, 0} = coord, acc -> coord |> extend_coords(:south) |> Enum.reduce(acc, &MapSet.put(&2, &1))
        {_, ^max_y} = coord, acc -> coord |> extend_coords(:north) |> Enum.reduce(acc, &MapSet.put(&2, &1))
      end)

    %{map | coord_set: new_set}
  end

  defp extend_coords({x, y}, :east) do
    case Enum.random(1..25) do
      n when n <= 2 -> [{x + 1, y}, {x, y + 1}, {x, y - 1}] ++ extend_coords({x + 1, y}, :east)
      n when n <= 4 -> [{x + 1, y}, {x, y + 1}] ++ extend_coords({x + 1, y}, :east)
      n when n <= 6 -> [{x + 1, y}, {x, y - 1}] ++ extend_coords({x + 1, y}, :east)
      n when n <= 15 -> [{x + 1, y}] ++ extend_coords({x + 1, y}, :east)
      _ -> []
    end
  end

  defp extend_coords({x, y}, :west) do
    case Enum.random(1..25) do
      n when n <= 2 -> [{x - 1, y}, {x, y + 1}, {x, y - 1}] ++ extend_coords({x - 1, y}, :west)
      n when n <= 4 -> [{x - 1, y}, {x, y + 1}] ++ extend_coords({x - 1, y}, :west)
      n when n <= 6 -> [{x - 1, y}, {x, y - 1}] ++ extend_coords({x - 1, y}, :west)
      n when n <= 15 -> [{x - 1, y}] ++ extend_coords({x - 1, y}, :west)
      _ -> []
    end
  end

  defp extend_coords({x, y}, :north) do
    case Enum.random(1..25) do
      n when n <= 2 -> [{x, y - 1}, {x + 1, y}, {x - 1, y}] ++ extend_coords({x, y - 1}, :north)
      n when n <= 4 -> [{x, y - 1}, {x + 1, y}] ++ extend_coords({x, y - 1}, :north)
      n when n <= 6 -> [{x, y - 1}, {x - 1, y}] ++ extend_coords({x, y - 1}, :north)
      n when n <= 15 -> [{x, y - 1}] ++ extend_coords({x, y - 1}, :north)
      _ -> []
    end
  end

  defp extend_coords({x, y}, :south) do
    case Enum.random(1..25) do
      n when n <= 2 -> [{x, y + 1}, {x + 1, y}, {x - 1, y}] ++ extend_coords({x, y + 1}, :south)
      n when n <= 4 -> [{x, y + 1}, {x + 1, y}] ++ extend_coords({x, y + 1}, :south)
      n when n <= 6 -> [{x, y + 1}, {x - 1, y}] ++ extend_coords({x, y + 1}, :south)
      n when n <= 15 -> [{x, y + 1}] ++ extend_coords({x, y + 1}, :south)
      _ -> []
    end
  end

  @shapes %{
    round: [{0, 0}, {0, 1}, {1, 1}, {1, 0}],
    flat: [{0, 0}, {1, 0}, {2, 0}],
    tall: [{0, 0}, {0, 1}, {0, 2}],
    dot: [{0, 0}]
  }

  def add_islands(%{bounds: {max_x, max_y}} = map, island_count) do
    new_coords =
      1..island_count
      |> Enum.map(fn _ ->
        shape = Enum.random([:round, :flat, :tall, :dot])
        coords = @shapes[shape]
        x_offset = Enum.random(0..max_x)
        y_offset = Enum.random(0..max_y)

        Enum.map(coords, fn {x, y} -> {x + x_offset, y + y_offset} end)
      end)
      |> List.flatten()
      |> MapSet.new()
      |> MapSet.union(map.coord_set)

    %{map | coord_set: new_coords}
  end

  def add_spawns(%{coord_set: set, bounds: {max_x, max_y}} = map, spawn_count) do
    possible_spawns =
      for x <- 0..max_x,
          y <- 0..max_y,
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
  def print(map) do
    do_print({0, 0}, map, [])
  end

  defp do_print({_, y}, %{bounds: {_, bound_y}}, output) when y > bound_y, do: IO.puts(output)

  defp do_print({x, y}, %{bounds: {bound_x, _}} = map, output) when x > bound_x,
    do: do_print({0, y + 1}, map, ["\n" | output])

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
