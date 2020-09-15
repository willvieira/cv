# Regex to locate links in text
find_link <- stringr::regex("
  \\[   # Grab opening square bracket
  .+?   # Find smallest internal text as possible
  \\]   # Closing square bracket
  \\(   # Opening parenthesis
  .+?   # Link text, again as small as possible
  \\)   # Closing parenthesis
  ",
                   comments = TRUE)

# Function that removes links from text and replaces them with superscripts that are 
# referenced in an end-of-document list. 
sanitize_links <- function(text){
  if(PDF_EXPORT){
    str_extract_all(text, find_link) %>% 
      pluck(1) %>% 
      walk(function(link_from_text){
        title <- link_from_text %>% str_extract('\\[.+\\]') %>% str_remove_all('\\[|\\]') 
        link <- link_from_text %>% str_extract('\\(.+\\)') %>% str_remove_all('\\(|\\)')
        
        # add link to links array
        links <<- c(links, link)
        
        # Build replacement text
        new_text <- glue('{title}<sup>{length(links)}</sup>')
        
        # Replace text
        text <<- text %>% str_replace(fixed(link_from_text), new_text)
      })
  }
  text
}

# Take entire positions dataframe and removes the links 
# in descending order so links for the same position are
# right next to eachother in number. 
strip_links_from_cols <- function(data, cols_to_strip){
  for(i in 1:nrow(data)){
    for(col in cols_to_strip){
      data[i, col] <- sanitize_links(data[i, col])
    }
  }
  data
}

# Take a position dataframe and the section id desired
# and prints the section to markdown. 
print_section <- function(position_data, section_id){
  position_data %>% 
    filter(section == section_id) %>% 
    arrange(desc(end)) %>% 
    mutate(id = 1:n()) %>% 
    pivot_longer(
      starts_with('description'),
      names_to = 'description_num',
      values_to = 'description'
    ) %>% 
    filter(!is.na(description) | description_num == 'description_1') %>%
    group_by(id) %>% 
    mutate(
      descriptions = list(description),
      no_descriptions = is.na(first(description))
    ) %>% 
    ungroup() %>% 
    filter(description_num == 'description_1') %>% 
    mutate(
      timeline = ifelse(
        is.na(start) | start == end,
        end,
        glue('{end} - {start}')
      ),
      description_bullets = ifelse(
        no_descriptions,
        ' ',
        map_chr(descriptions, ~paste('-', ., collapse = '\n'))
      )
    ) %>% 
    strip_links_from_cols(c('title', 'description_bullets')) %>% 
    mutate_all(~ifelse(is.na(.), 'N/A', .)) %>% 
    glue_data(
      "### {title}",
      "\n\n",
      "{loc}",
      "\n\n",
      "{institution}",
      "\n\n",
      "{timeline}", 
      "\n\n",
      "{description_bullets}",
      "\n\n\n",
    )
}


# Retrieve and edit publication list
get_publications <- function(ORCID, underlineName)
{
    # retrieve publication list from ORCID
    my_dois <- unique(rorcid::identifiers(rorcid::works(ORCID)))
    my_pubs <- rcrossref::cr_cn(my_dois, format = 'citeproc-json')

    # For each pub, organize title, journal, year, authors, and DOI
    editedPubs <- list()
    for(pub in my_pubs)
    {  
      # First get initials of given names
      Given <- gsub(' ', '‐', pub$author$given)
      Given <- strsplit(Given, '‐')
      Given <- lapply(Given, function(x) {paste(paste0(substring(x, 1, 1), '.'), collapse = '')})
      
      # Merge with family name
      familyName <- paste0(toupper(substr(pub$author$family, 1, 1)), tolower(substr(pub$author$family, 2, nchar(pub$author$family))))
      authors <- paste(familyName, Given, sep = ', ')

      # format my name to underlined
      authors <- gsub(underlineName, paste0('<span style="text-decoration: underline;">', underlineName, '</span>'), authors)
      
      # add to main list
      editedPubs[[pub$DOI]] <- list(title = pub$title, journal = pub[['container-title']], year = pub[['issued']][[1]][1], authors = paste0(authors, collapse = ', '), doi = pub$URL)
              
    }
    
    return( editedPubs )

}


print_publications <- function(pubs)
{
  for(pub in pubs)
  {
    print(
      glue::glue('
              ### {pub$title}
              \n
              {pub$journal} <a href="{pub$doi}" target="_blank"><i class="ai ai-doi"></i></a>
              \n
              N/A
              \n
              {pub$year}
              \n
              - {pub$authors}
              \n'
      )
    )
  }
}