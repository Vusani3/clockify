#' Title
#'
#' @param user_id
#' @param start
#' @param end
#' @param finished Whether to include only finished time intervals (intervals with both start and end time).
#'
#' @return
#' @export
#'
#' @examples
#' # Specify number of results per page (default: 50).
#' \dontrun{
#' time_entries(user_id, page_size = 200)
#' }
#' # Specify number of pages.
#' \dontrun{
#' time_entries(user_id, pages = 3)
#' }
time_entries <- function(user_id, start = NULL, end = NULL, finished = TRUE, ...) {
  path <- sprintf("/workspaces/%s/user/%s/time-entries", workspace(), user_id)

  query = list()

  if (!is.null(start)) {
    query$start = time_format(start)
  }
  if (!is.null(end)) {
    query$end = time_format(end)
  }

  entries <- paginate(path, query, ...)

  entries <- tibble(entries) %>%
    unnest_wider(entries) %>%
    unnest_wider(timeInterval) %>%
    clean_names() %>%
    select(
      id,
      user_id,
      workspace_id,
      project_id,
      billable,
      description,
      time_start = start,
      time_end = end
    )

  if (nrow(entries) == 0) {
    log_debug("No time entries for specified user.")
    entries <- tibble(
      id = character(),
      user_id = character(),
      workspace_id = character(),
      project_id = character(),
      billable = logical(),
      description = character(),
      time_start = character(),
      time_end = character()
    )
  }

  if (finished) {
    entries <- entries %>%
      filter(!is.na(time_end))
  }

  entries %>%
    mutate(
      time_start = time_parse(time_start),
      time_end = time_parse(time_end),
      duration = as.numeric(difftime(time_end, time_start, units = "mins"))
    ) %>%
    arrange(time_start)
}

#' Insert a time entry
#'
#' @param workspace_id
#' @param project_id
#' @param user_id
#' @param start
#' @param end
#' @param description
#' @param billable
#'
#' @return
#' @export
#'
#' @examples
#' \dontrun{
#' time_entry(
#'   workspace_id = "5ef23294df73064140f60bfc",
#'   project_id = "600e73263e207962449a2c13",
#'   start = as.POSIXct("2021-01-02 08:00:00"),
#'   end   = as.POSIXct("2021-01-02 10:00:00"),
#'   description = "Doing stuff"
#' )
#' }
time_entry <- function(
  workspace_id,
  project_id = NULL,
  user_id = NULL,
  start,
  end = NULL,
  description = NULL,
  billable = NULL
) {
  if (!is.null(user_id)) {
    # TODO: Need to hook up other endpoint to make this work for other users (premium feature).
    stop("Only able to insert time entries for current user!")
  }

  log_debug("Add time entry.")

  path <- sprintf("/workspaces/%s/time-entries", workspace_id)

  body = list()

  if (!is.null(start)) {
    body$start = time_format(start)
  } else {
    error("Start time must be provided!")
  }
  if (!is.null(end)) {
    body$end = time_format(end)
  }
  if (!is.null(project_id)) {
    body$projectId = project_id
  }
  if (!is.null(description)) {
    body$description = description
  }

  result <- POST(
    path,
    body = body
  )
  result <- httr::content(result)
  result
}
