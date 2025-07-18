#!/bin/bash

WORKDIR=$(dirname "$(dirname "$(readlink -f "$0")")")

build() {
  build_target=$1
  cd "$WORKDIR" && mkdir -p build && cd build && cmake .. >/dev/null && make "$build_target" -j >/dev/null
  if [[ $? != 0 ]]; then
    echo "Error: Compile error, try to run make build and debug"
    exit 1
  fi
}

test_lab1() {
  local score_str="LAB1 SCORE"
  local total_score=0
  local ref_dir=${WORKDIR}/testdata/lab1/refs

  build test_slp

  for test_num in {0..6}; do
    local ref=${ref_dir}/ref-${test_num}.txt
    ./test_slp $test_num >& /tmp/output.txt
    diff -w /tmp/output.txt "${ref}"
    if [[ $? != 0 ]]; then
      echo "Error: Output mismatch in test ${test_num}"
    else
      echo "[^_^]: Pass test ${test_num}"
      # Assign scores based on test number
      if [[ $test_num -le 3 ]]; then
        let total_score+=10
      else
        let total_score+=20
      fi
    fi
  done

  echo "${score_str}: ${total_score}"
}

test_lab2() {
  local score_str="LAB2 SCORE"
  local testcase_dir=${WORKDIR}/testdata/lab2/testcases
  local ref_dir=${WORKDIR}/testdata/lab2/refs
  local testcase_name

  build test_lex
  for testcase in "$testcase_dir"/*.tig; do
    testcase_name=$(basename "$testcase" | cut -f1 -d".")
    local ref=${ref_dir}/${testcase_name}.out
    sed -i 's/\r$//' "$testcase"
    sed -i 's/\r$//' "${ref}"
    ./test_lex "$testcase" >&/tmp/output.txt
    diff /tmp/output.txt "${ref}"
    if [[ $? != 0 ]]; then
      echo "Error: Output mismatch"
      echo "${score_str}: 0"
      exit 1
    fi
  done

  echo "[^_^]: Pass"
  echo "${score_str}: 100"
}

test_lab3() {
  local score_str="LAB3 SCORE"
  local testcase_dir=${WORKDIR}/testdata/lab3/testcases
  local ref_dir=${WORKDIR}/testdata/lab3/refs
  local testcase_name

  build test_parse
  for testcase in "$testcase_dir"/*.tig; do
    testcase_name=$(basename "$testcase" | cut -f1 -d".")
    local ref=${ref_dir}/${testcase_name}.out

    ./test_parse "$testcase" >&/tmp/output.txt
    res_run=$?

    # Check result of the run
    if [[ $testcase_name == "test49" ]]; then
      # A negative testcase
      if [[ $res_run == 0 ]]; then
        echo "Error: This testcase should incur syntax error [$testcase_name]"
        echo "${score_str}: 0"
        exit 1
      fi
      # Check output
      grep 'test49.tig:5.18: syntax error' /tmp/output.txt >&/dev/null
      if [[ $? != 0 ]]; then
        echo "Error: Output mismatch [$testcase_name]"
        echo "${score_str}: 0"
        exit 1
      fi
    else
      # Positive testcases
      if [[ $res_run != 0 ]]; then
        echo "Error: This testcase should not incur syntax error [$testcase_name]"
        echo "${score_str}: 0"
        exit 1
      fi

      # Check output
      diff /tmp/output.txt "${ref}"
      if [[ $? != 0 ]]; then
        echo "Error: Output mismatch [$testcase_name]"
        echo "${score_str}: 0"
        exit 1
      fi
    fi
  done

  echo "[^_^]: Pass"
  echo "${score_str}: 100"
}

test_lab4() {
  local score_str="LAB4 SCORE"
  local testcase_dir=${WORKDIR}/testdata/lab4/testcases
  local ref_dir=${WORKDIR}/testdata/lab4/refs
  local testcase_name

  build test_semant
  for testcase in "$testcase_dir"/*.tig; do
    testcase_name=$(basename "$testcase" | cut -f1 -d".")
    local ref=${ref_dir}/${testcase_name}.out

    ./test_semant "$testcase" >&/tmp/output.txt

    # Only check the error message part
    awk -F: '{print $3}' "$ref" >/tmp/ref.txt
    grep -Fof /tmp/ref.txt /tmp/output.txt >&/tmp/output_sel.txt
    diff -w -B /tmp/output_sel.txt /tmp/ref.txt
    if [[ $? != 0 ]]; then
      echo "Error: Output mismatch [$testcase_name]"
      echo "${score_str}: 0"
      exit 1
    fi
  done

  echo "[^_^]: Pass"
  echo "${score_str}: 100"
}

test_compiler() {
  local score_str="LAB TOTAL SCORE"
  local testcase_dir=${WORKDIR}/testdata/lab5or6/testcases
  local ref_dir=${WORKDIR}/testdata/lab5or6/refs
  local mergecase_dir=$testcase_dir/merge
  local mergeref_dir=$ref_dir/merge
  local runtime_path=${WORKDIR}/src/tiger/runtime/runtime.c
  local score=0
  local full_score=1
  local testcase_name
  local mergecase_name

  build tiger-compiler
  for testcase in "$testcase_dir"/*.tig; do
    testcase_name=$(basename "$testcase" | cut -f1 -d".")
    local ref=${ref_dir}/${testcase_name}.out
    local assem=$testcase.s

    ./tiger-compiler "$testcase" &>/dev/null
    gcc -Wl,--wrap,getchar -m64 "$assem" "$runtime_path" -o test.out &>/dev/null
    if [ ! -s test.out ]; then
      echo "Error: Link error [$testcase_name]"
      full_score=0
      continue
    fi

    if [[ $testcase_name == "merge" ]]; then
      for mergecase in "$mergecase_dir"/*.in; do
        mergecase_name=$(basename "$mergecase" | cut -f1 -d".")
        local mergeref=${mergeref_dir}/${mergecase_name}.out
        ./test.out <"$mergecase" >&/tmp/output.txt
        diff -w -B /tmp/output.txt "$mergeref"
        if [[ $? != 0 ]]; then
          echo "Error: Output mismatch [$testcase_name/$mergecase_name]"
          full_score=0
          continue
        fi
        score=$((score + 5))
        echo "Pass $testcase_name/$mergecase_name"
      done
    else
      ./test.out >&/tmp/output.txt
      diff -w -B /tmp/output.txt "$ref"
      if [[ $? != 0 ]]; then
        echo "Error: Output mismatch [$testcase_name]"
        full_score=0
        continue
      fi
      echo "Pass $testcase_name"
      score=$((score + 5))
    fi
  done
  rm -f "$testcase_dir"/*.tig.s

  if [[ $full_score == 0 ]]; then
    echo "${score_str}: ${score}"
  else
    echo "[^_^]: Pass"
    echo "${score_str}: 100"
  fi
}

main() {
  local scope=$1

  if [[ ! $(pwd) == "$WORKDIR" ]]; then
    echo "Error: Please run this grading script in the root dir of the project"
    exit 1
  fi

  if [[ ! $(uname -s) == "Linux" ]]; then
    echo "Error: Please run this grading script in a Linux system"
    exit 1
  fi

  if [[ $scope == "lab1" ]]; then
    echo "========== Lab1 Test =========="
    test_lab1
  elif [[ $scope == "lab2" ]]; then
    echo "========== Lab2 Test =========="
    test_lab2
  elif [[ $scope == "lab3" ]]; then
    echo "========== Lab3 Test =========="
    test_lab3
  elif [[ $scope == "lab4" ]]; then
    echo "========== Lab4 Test =========="
    test_lab4
  elif [[ $scope == "lab5" ]]; then
    echo "========== Compiler Test =========="
    test_compiler
  elif [[ $scope == "lab6" ]]; then
    echo "========== Compiler Test =========="
    test_compiler
  elif [[ $scope == "all" ]]; then
    echo "========== Lab1 Test =========="
    test_lab1
    echo "========== Lab2 Test =========="
    test_lab2
    echo "========== Lab3 Test =========="
    test_lab3
    echo "========== Lab4 Test =========="
    test_lab4
    echo "========== Compiler Test =========="
    test_compiler
  else
    echo "Wrong test scope: Please specify the part you want to test"
    echo -e "\tscripts/grade.sh [lab1|lab2|lab3|lab4|lab5|lab6|all]"
    echo -e "or"
    echo -e "\tmake [gradelab1|gradelab2|gradelab3|gradelab4|gradelab5|gradelab6|gradeall]"
  fi
}

main "$1"
