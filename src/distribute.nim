import std/[math, random, algorithm]

{.experimental: "views".}

func coefficientVariation(values: openArray[float]): float =
  if values.len < 2:
    0.0
  else:
      let n = values.len.float
      # TODO: Normalize values to positive
      let mean = sum(values) / n
      #echo "mean: ", mean
      let variance = block:
        var s: float
        for v in values: s += (v - mean)^2
        s / n
      let stdDev = sqrt(variance)
      #echo "var: ", variance, "stdd: ", stdDev, " CV: ", (stdDev / mean)
      abs(stdDev / mean)


func similarityScore*(factors: openArray[float]): float =
  ## Calculates the similarity score (between 0 and 1) of a list of factors.
  ## A higher score indicates that the factors are more similar.
  max(1.0 - coefficientVariation(factors), 0.0)


proc randFloatsSummingToOne*(n: Positive; sorted: bool = false): seq[float] =
  ## Returns a sequence of N random floats that sum up to 1.0.
  ## The implementation picks n-1 random numbers  between 0 and 1,
  ## adds 0 and 1 to the sequence to give n+1 numbers, sorting them
  ## and outputting the difference between each successive pair of numbers.
  if n == 1: @[1.0]
  else:
    var v = newSeq[float](n+1)
    v[0] = 0.0
    v[n] = 1.0
    for i in 1..<n:
      v[i] = rand(1.0)
    v.sort()
    for i in 0..<n:
      v[i] = v[i+1] - v[i]
    v.setLen(n)
    if sorted: v.sorted() else: v


when isMainModule:
  import unittest

  suite "similarityScore":
    test "Test empty list":
      let score = similarityScore([])
      check(score == 1.0)

    test "Test two values":
      let score = similarityScore([0.0, 1.0])
      check(score == 0.0)

    test "Test single element list":
      let score = similarityScore([1.0])
      check(score == 1.0)

    test "Test list with identical elements":
      let factors = [2.0, 2.0, 2.0, 2.0]
      let score = similarityScore(factors)
      check(score == 1.0)

    test "Test list with different elements":
      let factors = [1.0, 2.0, 3.0, 4.0, 5.0]
      let score = similarityScore(factors)
      check(score == 0.5285954792089682)

    test "Test list with negative elements":
      let factors = [-1.0, 0.0, 1.0]
      let score = similarityScore(factors)
      check(score == 0)

    test "Test list with zero":
      let factors = [2.0, 0.0, 4.0, 0.0] # stdd 1.66, cv 1.11
      let score = similarityScore(factors)
      check(score == 0)

    test "Test list with repeated elements":
      let factors = [1.0, 2.0, 3.0, 3.0, 3.0]
      let score = similarityScore(factors)
      check(score == 0.6666666666666666)

  suite "randFloatsSummingToOne":
    test "Test that the sum of the generated floats is 1":
      for i in 1..100:
        let floats = randFloatsSummingToOne(i)
        let sum = floats.sum()
        check abs(sum - 1.0) < 1e-6

    test "All the generated floats are between 0 and 1":
      for i in 1..100:
        let floats = randFloatsSummingToOne(i)
        for x in floats:
          check x >= 0.0 and x <= 1.0
